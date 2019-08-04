using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using Microsoft.Azure.EventHubs;
using Microsoft.Azure.WebJobs;
using Microsoft.Extensions.Logging;
using Newtonsoft.Json.Linq;

namespace DM
{
    public class ChangeFeedParser
    {
        private JObject _body;
        private JObject _schema => (JObject)(_body["schema"]);
        private JObject _payload => (JObject)(_body["payload"]);
        private JObject _source => (JObject)(_payload["source"]);
        private Dictionary<string, string> _fields = new Dictionary<string, string>();

        public ChangeFeedParser(JObject body)
        {
            _body = body;
            var fields = (JArray)(_schema["fields"][0]["fields"]);

            foreach (var f in fields.ToArray())
            {                
                string name = f["field"].ToString();
                string type = f["type"].ToString();
                string debeziumType = f["name"]?.ToString();
                _fields.Add(name, debeziumType ?? "");
            }
        }

        public object GetValue(string section, string fieldName)
        {
            var property = ((JObject)_payload[section]).Property(fieldName);
            
            string result = property.Value.ToString();
            string debeziumType = _fields[property.Name];

            if (string.IsNullOrEmpty(_fields[property.Name])) // not a debezium data type
            {
                return result;
            }
            else
            {
                DateTime epoch = new DateTime(1970, 1, 1, 0, 0, 0, DateTimeKind.Utc);

                switch (_fields[property.Name])
                {
                    case "io.debezium.time.Date":
                        var daysFromEoch = Int32.Parse(result);
                        return epoch.AddDays(daysFromEoch);

                    case "io.debezium.time.NanoTimestamp":                       
                        long elaspedNanoSeconds = Int64.Parse(result);                        
                        return epoch.AddTicks(elaspedNanoSeconds / 100);

                    default:
                        throw new ApplicationException($"'{debeziumType}' is unknown");
                }
            }
        }
    }

    public static class ProcessDebeziumPayload
    {
        [FunctionName("ProcessDebeziumPayload")]
        public static async Task Run([EventHubTrigger("wwi", Connection = "debezium")] EventData[] events, ILogger log)
        {
            var exceptions = new List<Exception>();

            foreach (EventData eventData in events)
            {
                try
                {
                    if (eventData.Body.Array.Length > 0)
                    {                    
                        string messageBody = Encoding.UTF8.GetString(eventData.Body.Array, eventData.Body.Offset, eventData.Body.Count);

                        log.LogInformation(messageBody);
                        
                        var body = JObject.Parse(messageBody);                        
                        var schema = (JObject)body["schema"];                            
                        var payload = (JObject)(body["payload"]);                        
                        var source = (JObject)payload["source"];

                        var parser = new ChangeFeedParser(body);

                        log.LogInformation("Event from Change Feed received:");
                        log.LogInformation("- Object: " + source["schema"] + "." + source["table"]);                                              
                        log.LogInformation(parser.GetValue("after", "LastEditedWhen").ToString());

                    }
                    await Task.Yield();
                }
                catch (Exception e)
                {
                    // We need to keep processing the rest of the batch - capture this exception and continue.
                    // Also, consider capturing details of the message that failed processing so it can be processed again later.
                    exceptions.Add(e);
                }
            }

            // Once processing of the batch is complete, if any messages in the batch failed processing throw an exception so that there is a record of the failure.

            if (exceptions.Count > 1)
                throw new AggregateException(exceptions);

            if (exceptions.Count == 1)
                throw exceptions.Single();
        }
    }   
}

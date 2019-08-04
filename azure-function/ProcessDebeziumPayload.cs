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
    public class Utils
    {
        public static readonly DateTime Epoch = new DateTime(1970, 1, 1, 0, 0, 0, DateTimeKind.Utc);        
    }

    public class TableInfo 
    {
        public readonly string Schema;
        public readonly string Table;
        public readonly DateTime ChangedAt;

        public TableInfo(string schema, string table, DateTime timeStamp)
        {
            this.Schema = schema;
            this.Table = table;
            this.ChangedAt = timeStamp;
        }
    }
    
    public class Fields 
    {        
        private JObject _body;
        private readonly string SectionName;
        private JObject _schema => (JObject)(_body["schema"]);
        private JObject _section => (JObject)(_body["payload"][SectionName]);
        private Dictionary<string, string> _fields = new Dictionary<string, string>();

        public Fields(JObject body, string sectionName)
        {
            _body = body;
            SectionName = sectionName;

            var fields = (JArray)(_schema["fields"][0]["fields"]);

            foreach (var f in fields.ToArray())
            {                
                string name = f["field"].ToString();
                string type = f["type"].ToString();
                string debeziumType = f["name"]?.ToString();
                _fields.Add(name, debeziumType ?? "");
            }
        }

        public object GetValue(string fieldName)
        {
            var property = (_section).Property(fieldName);
            
            string result = property.Value.ToString();
            string debeziumType = _fields[property.Name];

            if (string.IsNullOrEmpty(_fields[property.Name])) // not a debezium data type
            {
                return result;
            }
            else
            {                
                switch (_fields[property.Name])
                {
                    case "io.debezium.time.Date":
                        var daysFromEoch = Int32.Parse(result);
                        return Utils.Epoch.AddDays(daysFromEoch).Date;

                    case "io.debezium.time.Time":
                        var millisecondFromMidnight = Int32.Parse(result);
                        return Utils.Epoch.AddMilliseconds(millisecondFromMidnight).TimeOfDay;

                    case "io.debezium.time.MicroTime":                       
                        var elapsedMicroSeconds = Int64.Parse(result);                        
                        return Utils.Epoch.AddTicks(elapsedMicroSeconds * 10).TimeOfDay;

                    case "io.debezium.time.NanoTime":                       
                        var elapsedNanoSeconds = Int64.Parse(result);                        
                        return Utils.Epoch.AddTicks(elapsedNanoSeconds / 100).TimeOfDay;

                    case "io.debezium.time.Timestamp":                       
                        var elapsedMilliseconds = Int64.Parse(result);                        
                        return Utils.Epoch.AddMilliseconds(elapsedMilliseconds);

                    case "io.debezium.time.MicroTimestamp":                       
                        var elapsedMicroSeconds2 = Int64.Parse(result);                        
                        return Utils.Epoch.AddMilliseconds(elapsedMicroSeconds2 * 10);

                    case "io.debezium.time.NanoTimestamp":                       
                        var elapsedNanoSeconds2 = Int64.Parse(result);                        
                        return Utils.Epoch.AddTicks(elapsedNanoSeconds2 / 100);

                    default:
                        throw new ApplicationException($"'{debeziumType}' is unknown");
                }
            }
        }
    }

    public class ChangeFeedParser
    {
        private JObject _body;

        private JObject _payload => (JObject)(_body["payload"]);
        private JObject _source => (JObject)(_payload["source"]);
        public TableInfo TableInfo { get; private set;}
        public readonly Fields After;
        public readonly Fields Before;

        public ChangeFeedParser(JObject body)
        {
            _body = body;            

            TableInfo = new TableInfo(
                schema: _source["schema"].ToString(),
                table: _source["table"].ToString(),
                timeStamp: Utils.Epoch.AddMilliseconds(Int64.Parse(_source["ts_ms"].ToString()))
            );

            Before = new Fields(body, "before");
            After = new Fields(body, "after");
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
                        var parser = new ChangeFeedParser(body);

                        log.LogInformation("Event from Change Feed received:");
                        log.LogInformation("- Object: " + parser.TableInfo.Schema + "." + parser.TableInfo.Table);                                              
                        log.LogInformation("- Captured At: " + parser.TableInfo.ChangedAt.ToString("O"));  

                        log.LogInformation("> ExpectedDeliveryDate: " + parser.After.GetValue("ExpectedDeliveryDate"));
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

using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using Microsoft.Azure.EventHubs;
using Microsoft.Azure.WebJobs;
using Microsoft.Extensions.Logging;
using Newtonsoft.Json.Linq;

namespace Azure.SQLDB.ChangeDataCapture.Debezium.Sample
{
    public static class ProcessDebeziumPayload
    {
        [FunctionName("ProcessDebeziumPayload")]
        public static async Task Run([EventHubTrigger("wwi", Connection = "Debezium")] EventData[] events, ILogger log)
        {
            var exceptions = new List<Exception>();

            foreach (EventData eventData in events)
            {
                try
                {
                    if (eventData.Body.Array.Length > 0)
                    {                    
                        string messageBody = Encoding.UTF8.GetString(eventData.Body.Array, eventData.Body.Offset, eventData.Body.Count);

                        //log.LogInformation(messageBody);
                        
                        var body = JObject.Parse(messageBody);                        
                        var parser = new ChangeFeedParser(body);

                        log.LogInformation("Event from Change Feed received:");
                        log.LogInformation("- Object: " + parser.TableInfo.Schema + "." + parser.TableInfo.Table);                                              
                        log.LogInformation("- Operation: " + parser.Operation.ToString());
                        log.LogInformation("- Captured At: " + parser.TableInfo.ChangedAt.ToString("O"));  

                        Fields fields;
                        if (parser.Operation == Operation.Insert || parser.Operation == Operation.Update)
                            fields = parser.After;
                        else
                            fields = parser.Before;                        

                        foreach(var f in fields) 
                        {
                            log.LogInformation($"> {f.Name} = {f.Value}");
                        }
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
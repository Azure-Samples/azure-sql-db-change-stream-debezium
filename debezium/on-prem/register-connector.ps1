$JSON = Get-Content '..\register-sqlserver-eh.json' | Out-String
Invoke-RestMethod http://localhost:8083/connectors/ -Method POST -Body $JSON -ContentType "application/json"     

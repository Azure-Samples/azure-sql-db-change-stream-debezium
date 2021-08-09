## script used to import a db in dacpac format into SQL Azure
./sqlpackage.exe /a:import /tcs:"Data Source=\<your SQL Azure Server\>.database.windows.net;Initial Catalog=WideWorldImporters;User Id=\<User Id\>;Password=\<Your password\>" /sf:\<Path on your machine to the downloaded file\>\WideWorldImporters-Standard.bacpac /p:DatabaseEdition=Premium /p:DatabaseServiceObjective=P6

**NOTE**: u must run this script where u have installed the sqlpackage utility on your machine.
**NOTE 2**: replace the text between angle brackets with your params.

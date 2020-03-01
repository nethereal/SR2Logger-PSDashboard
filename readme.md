This isn't even Alpha grade code. 

Requirements:
	SR2 running in 1280 x 800 (dont ask, just do it)
	SR2Logger mod installed and enabled
	this git repo cloned locally on your disk

Instructions:

	Copy SR2Logger_All.xml into your FlightPrograms folder

	launch or Powershell ISE

	Make sure to expand the down arrow to see the top half "script" part of the window

	navigate in the shell below (blue) to the directory with the code

	open the "servertest1.ps1" file in ISE and modify line 148:
		$endTime = $startTime.AddSeconds(60)

	change 60 to whatever duration you want the code to run.

	(try to allow the code to end gracefully, i cant predict behaviour otherwise)

	launch SR2 and load up your craft. Add the orange black box.

	Edit program on orange black box, and load the program you copied earlier (SR2Logger_All)

	Save program to part

	start your flight and activate the orange black box to begin the data output

	execute the script in powershell ISE (you can use the green arrow at the top or hit F5) 


***
To close the panes: 
	click in an individual pane, and hit Alt+F4
(I will be adding some gui control elements in the future) 
***

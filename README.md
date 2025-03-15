# Steam Zipper
Loop through steam games folder, zipping each folder and giving it a unique name (PS edition).

I'm not assuming this exact script hasn't already been done in many other languages many, many times before. I'm just doing this to try and backup my steam games. And practice PS scripting.

### Current Script status: Work - Minimum viable functionality
(the flagged "release" is good)

The current 15 March version (not tagged as a version yet) works with WhatIf. I haven't thuroughly tested it yet though. It won't be hard to find a combination of parameters that breaks the script. So...don't do that. Or fix it. 

I've decided to make a version a new "alpha build" and also just use the script name ```steamzipper.ps1```.

USAGE:
```steamzipper.ps1 -sourceFolder  <source folder> -destinationFolder <destination folder> <optional: debubMode> <optional: keepDuplicates> <optional: verbMode> <optional: compressionLevel: [optimal | Fastest | None]> [<optional: createAnswerFile> | <optional: answerFile:answer.txt>] <optional: WhatIf> ```

note: this is how to use a generated answer file
```pwsh -command '& { .\steamzipper.ps1 -answerFile:answer.txt }'```

The script attempts to identify a platform, like Steam, by identifying the name in the source folder path. 

To generate the name of the zip file it takes into account 
- the last modified date of the source folder (converted to 8-digit format), 
- the platform
- replaces any spaces in the source folder name with underscores (probably not necessary but I'm keeping it)

Example:

```.\steamzipper.ps1 -sourceFolder "P:\Program Files (x86)\Steam\steamapps\common" -destinationFolder "P:\steamzipper\backup\" ```

I should perhaps mention I've been running all my tests with a line like this:
```pwsh -command '& { .\steamzipper.ps1 -sourceFolder "c:\steamzipper\steam temp storage" -destinationFolder "c:\steamzipper\zip test output" -debugMode -VerbMode  }'```

Example archive name would be something like:
```Horizon_Chase_10152024_steam.zip```

I'm American so I can't break the month-day-year habit. Easy to modify...

**What works as of this milestone:**
I've tested as many combinations of 
- debugMode (only useful for writing the script), 
- verbMode (lengthy transcript file good for development) and 
- keepDuplicates, which allows for as many generated zip files as you would like.
- a transcript file is automatically generated in the same folder as the script. 

**What has not been tested/won't work:**
As of now the date format, like month-day-year, for the zip file names are defined as a global variable at the top of the script. If you run the script to get some zip files then go back and change the defined date format (to day-month-year for instance) the script will not know how to deal with this. I might add this extra layer of robustness in the future. For now just define your date format before running it or delete all the zips before re-running it with a new date format.

There's no help documentation or -what-if yet. 

**You may want to test this on a few game folders first (copy/past some small games to a separate folder and run the script against that)**

### Installation


Since this is a single PowerShell script, that is the only thing required. You can view the source "raw" and copy/paste into notepad, or download a zip file from the green "code" button or use the tags link and click on *v1.0-beta.3* (I realize my version numbering schemes are all over the place but stick with me) to find a zip file. Or just clone the repo. Any of those ways will get you the script file which you would just run from PS console. So far as I know local admin privileges should not be required. 

As for permissions to run PS1 files in general that's between you and your PC administrator.

If I polish it more (and add an ascii art based logo, obviously) I might try and make a "package" for use with PSGallery etc. That is definitely far off.

Prior versions:
*v0.2.0-beta.1*

### Feature Wishlist 

- Zipping multiple files at once using a job pool (like dogpool but uglier)
- A companion script that as a batch or selectively on unzips the games to a destination
- Some form of UI, at least as an option, would be nice. I'll just use the one that comes with Python. Or the thing I just found out about, [PwshSpectreConsole](https://spectreconsole.net/).
- really far off: make what is used for compressing the folders more modular e.g. you can use a PS replacement for the compress-archive cmdlet such as  7zip, winrar or some other utility. 
- implement a what-if parameter that shows what operations would and in a perfect world an estimate of how much disk space that would require and how much appare space there is on the destination storage device
- create a version (or refactor, whatever) of it to exist on the PS packages site (gallery)
  - I'm not paying for a certificate though
  ---
- implement way of provided a text file list of folders to be compressed in place of destination path **[done]**
- a log file of success failure of items like creating the destination folder it doesn't exist successfully zip a folder **[done]**
- more/better error checking and dealing with the errors (effectively done)
- Some semblance of dealing with duplicate zips via parameter or whatever **[done]**
- created config file or "answer file" for repeat running **[done]**
- - an argument to select a compression level besides the default **[done]**

Might be a little much just for a thing that zips some folders.


---
### 15 March 2025

I was able to get -WhatIf properly working (probably?) and also tested WhatIf with a combination of different parameters such as debug and verbmode (which don't really matter to any one but developers).

I also realized I could just redirect console output to a text the same I could with CMD. Not sure why I didn't try that sooner.

So this command
```pwsh -Command ".\steamzipper.ps1 -sourceFolder 'P:\steamzipper\steam temp storage' -destinationFolder 'P:\steamzipper\zip test output' -WhatIf -debugMode -VerbMode" > .\whatif-debug-output.txt```

works perfectly well. I need this because -WhatIf doesn't generate the transcript file as the other parameters do and I still need the console output for copy/pasting and readibility. 



### 14 March 2025

Well. A few things have changed since that last updated. 

Firstly my LLM assistant couldn't deal with the regression testing script so I've abandoned that for now. If I go back to that I'll write it myself from scratch (e.g. no LLM help).

Secondly I ended up goback to an old version of the script. Well slightly older. I just had re-add the createAnswerfile/answerfile parameters and put the folders text file list back in. So I lost relatively little. It's my own fault for using an LLM.

Those three features (create answer file, use answer file and used folder text file as source) should all be added back in now. I haven't thoroughly tested them yet. Just enough to see they work in at least one circumstance.

I also added a PS version detection line to make sure the script is run only in PS 7.x and later.

### 10 March 2025

- finally got a milestone for a working version of the regression test script. This script ended up with static paths and file name lists so it would require editing if someone else wanted to try to use it for some reason.

### 9 March 2025

I think the past week was just leading up to today. Since I ended up implementing so many things.

Today I have added the following:

- create answer file: generates a JSON formatted text file containing all the parameters
- use answer file: specify a generated answer file to use that as the list of parameters (in case repeated runs are necessary)
- must now specify source and destination manually in the command line as in the following. This was to make sure the answer file functionality worked.
```pwsh -command '& { .\steamzipper.ps1 -sourceFolder "P:\steamzipper\steam temp storage" -destinationFolder "P:\steamzipper\zip test output" -debugMode -VerbMode -keepDuplicates -CompressionLevel Fastest -createAnswerFile:answer.txt }' ```     
- Added a measure-command around zip compression command to display how long the compression took (rounded to the nearest 10th of second).
- Actually I am no longer sure when I added the compression parameter, further info: the default compression for the compress-archive cmdlet is "optimal". So you can use that parameter if you want but leaving out the compressionLevel parameter will just use the "optimal" setting. The measure-command isn't used when -debugMode parameter specified (it would be timing creation of a 0 KB file).
- can now specify a text file with a list of folders to be compressed, one folder name per line (defaults to looking for txt file in the script folder). This is so a user can optionally only back up specific folders. See folders.txt in the repo for an example. Sample command line:
```pwsh -command '& { .\steamzipper.ps1 -sourceFolder "P:\steamzipper\steam temp storage" -destinationFolder "P:\steamzipper\zip test output" -sourceFile "C:\SteamZipper\folders.txt" -debugMode -VerbMode -keepDuplicates -CompressionLevel Fastest }'```
- I just realized this is the only way to use the generated answer file:
```pwsh -command '& { .\steamzipper.ps1 -answerFile:answer.txt }'```
- I'm also starting development on a automated regression testing script, but this won't help anybody besides me in attempted development. And it's not done yet. Or exist techncially. Soon.


### 8 March 2025

I did some repo house cleaning and I'm back to using "steamZipper.ps1" as the script name. I updated the repo to a version with some functionality at least. This version could be used as of now to back up steam games. 

The parameters keep duplicates, debugMode and verbMode should work in any combination. And I have developed a testing work flow I think accurately reflects some basic edge cases.

I should perhaps mention I've been running all my tests with a line like this:
```pwsh -command '& { .\steamzipper.ps1 "c:\steamzipper\steam temp storage" "c:\steamzipper\zip test output" -debugMode -VerbMode  }'```

### 7 March 2025

I decided I wanted to spend a lot more time on this script and I ended up not updating my progress log here. I went through mulitple iterations of the script to get to where it is right now: it actually works for compressing steam folders. It deals with duplicate zips, it compares dates across folders and zip files, it skips over small sized folders that don't need to be compressed. But I still have some re-factoring and more features to add (like what-if and some help documentation).

And I started using the file ```hashtable_build - milestone-entirety of functionality.ps1``` for some reason.


### 3 February 2025

I'm stilling filling in the functions from the old versions into this v3. I haven't even tried test running it quite yet. Hopefully this process won't take too much longer.

### 1 February 2025

I certainly took a long time off. I decided to re-write the script with a few things in mind from the start and call it v3. Even though v2 is still broken. 

I did start to implement a JSON file for saving preferences and Start-Transcript for logging what happens. That's about it. I haven't even run it yet. Just working on it.



### 12 December 2024

I didn't intend to take a long break but I'm back at it now.

I was working on this edge case in which I found multiple existing zip files in the destination. This apparently automatically creates an iteratable object containing the names of both zip files. And also an array of one item if there was just he one match. 

I ended up typcasting that to an Array-for-sure-type. Then I was getting this error from PS when there no matches in that initial filter search. So I eventually found that -notcontains is an option. 

```
if (  ($getchildReturn -notcontains $null) -and (Test-Path $getchildReturn)  -and (Test-Path $DeletePath) ) {
        try {
            Write-Host "successfullyl deleted $justFilename (or moved, as the case may be)" -BackgroundColor Green -ForegroundColor White
        } catch {
            Write-Host "Unable to delete file $justFilename"
        }
    }
} else {
    Write-Host "The zip files date - $zipfiledateAsDate - is equal to or newer than the folder's last write date - $fileDatestamp so new zip does not need`
to be created (inside DetermineZipStatusDelete)"
```

It may not make sense out of context but this is what's working for me. 

Also, while trying random things with Test-path, I found what appeared to a way to test if file objects are older or newer than other file objects. Which is what I've been trying to do this whole time. Really wish I had found this sooner. This is [convered breifly in a blog entry I found](https://lazyadmin.nl/powershell/test-path/). I may have to use Test-Path instead of what I've been doing. 

### 16 November 2024

I have re-re-done the functions for the date comparisons - again. Somewhere I picked up a bug where I was getting the write date back for the source folder as opposed to the game subfolder. Took a while to figure that out. 

I saved that with this one line:

```$CurrGameDir = Join-Path -path $sourceFolder -ChildPath $_.name```

And a lot of debugging print lines. Many, many print lines. 

After only a week to figure out like two lines, I might be ready to resume what I was doing before. Okay it might have been two weeks. But "oh who remembers"?

I actually did a lot of testing in ```testing.ps1```. Almost re-created the entire script just to test things. It might have ended up making it take longer than it would have other wise. Well maybe not. I should probably learn more git. Since it's made for this exact purpose.

As of now my series of functions that tests and compares dates of folders and zip files is working. And using the ```-KeepDuplicateZips``` flag actuall results in a different series of write-lines. 

So progress however slight is still progress.

On a probably entirely separate note, i realized my variables seemed to be persistent across running of the script over and over again. So I came up with running the script this way:

```pwsh -command '& { .\steamzipper-v2.ps1 "P:\steamzipper\steam temp storage" "P:\steamzipper\backup-steam\" -KeepDuplicateZips }'```

This runs the script in a PS session and exits when it's done, leaving all those variable values hopefully behind. Kind of like my favorite of ```cmd /c``` but for powershell. I also started coloring different parts of my debug writelines. Probably should have done that sooner.

### 8 November 2024

I did and re-did that zip-file-exists true/false function again. Or again by 30 times it seems like. Anyway I hope it's good now because I'm pretty sick of it.

Now I'm working on my next function:

1. extract date code from zip file name
2. convert this date to a date object
3. grab last write date from source folder (should be date object)
4. compare the two dates to determine which is newer
   1. if zip is newer than folder no action needed (zip already contains latest version of folder)
   2. if zip is older than folder 
      1. delete current zip file
      2. lets folder stay in list for zipping 

It also occurred to me to add an optional parameter to simply specify a platform. Instead of cleverly extracting the platform from the path. Not sure it's really necessary but I'll worry about it later.


### 2 November 2024

Well. It took me entirely too long - had to take the scenic route as usual - but I think I have my latest function actually done.

It could actually be multi-functional but I think I'm going to break it up. I'll see later if I need to go back and combine into one.

This new function - currently called determineExistZipFile - takes in a zip file name (like Horizon_Chase_10152024_steam.zip) and uses Get-ChildItem to determine if there's already a zip file with the first part of the name in the destination folder.

In other words I can't test against Horizon_Chase_10152024_steam.zip so I have to cut off the date stamp and platform name. But file names will vary by the number of underscores and lengths. So I need to test against Horizon_Chase, in other words. But use that on *all* zip file names. 

If an existing zip file is found return true. If not return false. That's the whole functionality.

I did learn a lot. Like this for instance:
```$zipNoExtra = $($ZipNameBreakout[0..$($target)])```
I've never used that [0..x] syntax before but I'm glad it worked. If you're wondering what it means: array elements are accessible with the [] notation, the first element being 0. But you can access the last element with [-1]. So if there's an array of inderminate length, -1 will always be the last element. So [0..-3] is "everything between the first element and the third to last element in the array". Steam and "10152024" are the -1 and -2 elements of all the zip file names. 

If a zip files *does* already exist, the companion function will isolate the "10152024" from Horizon_Chase_10152024_steam.zip and convert it to a date datatype then bring in the date code for a pending zip file (obtained from the source folder) and compare the two. If the folder is newer than the zip date then proceed to making a zip. And also delete the current zip. If the zip is newer than the folder no need to make a new zip file.

No idea if that made sense. 

I worked on this determineExistZipFile function pretty much all day today. I had it working the way I wanted except for this extra "True" or "False" that kept outputing.

Turns out my crucial Get-ChildItem command was showing me these True/False even though I didn't ask for any output. I was doing a weird test though: Get-ChildItem on a directory with a filter condition. If get-childitem returned a result it was true otherwise false. So not a traditional boolean you might say.

I tried everything trying to figureout how to get it to stop outputting like that but couldn't figure it out.

I inadvertently found solution: assign the variable to the GetChild-Item which is in parens and piped to measure-object and after that close parens, a *.count*. So the variable is storing a number (integer) rather than the file list of the directory. 

I also did some weird typing stuff in that determineExistZipFile function. I don't know why it works but it does. So I'm not going to touch it.

### 31 October 2024

I'm trying to refactor the script again. I've created additonal global variables, flagged them as global and set them to read-only. These are values end users can easily adjust but not important enough to add as separate parameters.

I have update the Get-FileDateStamp function to hopefully be more readable and robust and actually added a feature that doesn't really do anyting at the moment. Maybe it will be useful in the future.

I have refactored the BuildZipTable entirely - I generate the two lists that will populate the hashtable as I'm going through source subfolder and also constructing the zip name. A much better use of a loop and way to do do these two things. 

There is also a space for adding exclusion for what is not going into the lists such as empty folders or paths the user doesn't want to include (I would exclude SteamVR, for instance).



### 29 October 2024

I implemented the new date function today. The script is running as it did previously so I'm calling this a success.

It did occur to me I don't really want to deal with duplicate zips. I've gone back and forth on my thinking with this but now I think I've about made up my mind: if there's an existing zip file in the destination and the script determines a new zip file is necessary the existing zip should be deleted and a new one created. The new one will have a different name so it doesn't really matter which happens first. I can add a flag to keep duplicates if that's really necessary. I think it makes more sense to default to deleting duplicates though. 

Or maybe I'm coming up with random changes because I want to avoid the jobs implementation. Because it will probably take a long time and be really anoyingly difficult.

Good news and bad news. Or just neutral then:
I'm implmementing parallel zipping with jobs but I'm using a form of ```ForEach-Object``` that requires PS 7. Only really an issue if you're unable to install the latest PS for some reason. 

On a separate note, [the documentation for ForEach-Object on the Microsoft developer site](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/foreach-object?view=powershell-7.4) is actually really good.

### 28 October 2024

Today I actually re-wrote the function for handling dates: pass in the path of either a folder or a zip file and back out a date object. I didn't re-implement to actually to use this newly designed function, but it seems to be working correctly in testing. 

### 21 October 2024

I found a rather obvious logic bug in my date comparison code today. It turns out I was comparing the folder last modified date to the folder last modified date. Although I was using -lt which is less than, not equal to or less than. So I'm not even sure why it was working in my testing. There's probably a further logic bug there I'm not catching. Using less than with a string type for instance. Is that typecasting to an integer silently so it works? Or am I missing something? 
**Update:** see I couldn't let it go. Ended up type casting any/all 8 digit date codes to actual date objects then using the -lt comparison. I'm glad I went back and did that. String or integer 8 digit date code comparisons would never have worked.

I added a variable to define the date format at the top of the script. Simply change the variable value to your preferred format if (if that isn't month-day-year). Further instructions are in the script comments.

*Anyway* I could probably add some additional polish to this script before starting on jobs. Something involving the *try* keyword. But instead I'll assume I can add that later if needed.

I don't know how many hours I spent on this script today. I'm going to go with "a lot". I tried to start the jobs part of it but made relatively little progress on it. I mean I learned a lot. But the jobs aren't really working.

I added an optional parameter: jobs-enabled. So leave that parameter out and it still has the "normal" functionality (one zip at a time). Or add that parameter and glory in the scripts brokenness. The jobs function is only defined if the parameter is present. I'm sure I'm the first one to figure that out.

It did of course occur to me at some point I don't *have* to try and manage all these zip jobs. I could loop through and slap **&** at the end of the line and try and keep up with displaying status that way. That seems *so much easier* than dealing with start-job.

### 20 October 2024

I commented out a function I wasn't using, at least for now.

Also re-organized the Go-SteamZipper function to take out the write-progress attempt. Then aded a "zipping file of (file name) number of number". Well that still needs work. So not a lot of contribution. 

### 19 October 2024

I'm implemented the date stamp comparison between folder and zip file. It may need more testing but as far as I can tell it's working.

I also put in a check to make sure the folder to be backed up isn't empty. No need to back up a 0KB folder, right? So it checks to make sure the folder in question is larger than 100KB.

I mean I did this is one big if condition which isn't ideal. But at least it's working as far as I can tell.

### 18 October 2024

The script is essentially done as of now. Done in the sense it does in fact loop through the subfolders of a folder, add the subfolders to a zip archive, and save the zip in a specific destination folder.

I *could* add additional functionality: use PS jobs so multiple zips are created at once, some kind of progress bar to track how many are done and how many are left, and something to deal with duplicate zip files (in case multiple zips of the ~50 gigabyte Elden Ring could be an issue). I could also let the user specify a compression level.

All that aside, though, the script is doing what I set out to do.

### 17 October 2024

I made quite a bit of progress today on the re-write. I'm going one very small increment at a time. I got as far as zipping some folders but there's still a lot left.

### 15 October 2024

First version written Oct. 15th. Okay I didn't write it an AI did. Which is why I'm trying to re-write it from scratch as the original currently doesn't work. I had a working version. I asked for new features and now it doesn't work. Instead of reverting to the working version I'm re-writing it myself. It's better this way anyway. 

---

```
A perpetually grunting man-freak-beast dressed in WWII-garb semi-terrorizes the French countryside.
Meanwhile, a vacationing couple take shelter in an ominous, gothic chateau for the night. The elderly 
keepers of the grand castle tell a tale of a galleon running aground from five pillagers setting a 
huge bonfire on a nearby beach to lure the ship in. This prompts the old drunkard owner to take a 
shotgun with unlimited ammo out to murder a wild black stallion for ten continuous hours. The ghostly 
galleon then erupts from a cake doubling as a mountainside as its contents of barrels and an 
Egyptian casket spill forth. A mummy emerges with a thunder clap and the young vacationing woman 
ends up in the middle of it all in a fight for survival after leaving the safety of the medieval fortress.
Color / 73 mins / 1985
HORSE! HORSE! HORSE! HORSE! HORSE! HORSE! HORSE! HORSE! 
```

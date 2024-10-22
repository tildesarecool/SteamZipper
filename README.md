# Steam Zipper
Loop through steam games folder, zipping each folder and giving it a unique name (PS edition).

I'm not assuming this exact script hasn't already been done 
in many other languages many, many times before. I'm just 
doing this to try and backup my steam games. And practice 
PS scripting.

USAGE:
```steamzipper-v2.ps1 <source folder> <destination folder> <optional: enable-jobs> ```

(enable-jobs is broken)

The script attempts to identify a platform, like Steam, by identifying the name in the source folder path. 

To generate the name of the zip file it takes into account 
- the last modified date of the source folder (converted to 8-digit format), 
- the platform
- replaces any spaces in the source folder name with underscores (probably not necessary but I'm keeping it)

Example:

```.\steamzipper-v2.ps1 "P:\Program Files (x86)\Steam\steamapps\common" "P:\steamzipper\backup\" ```

Example archive name would be something like:
```Horizon_Chase_10152024_steam.zip```

I'm American so I can't break the month-day-year habit. Easy to modify...

This is the hashtable I have for the platforms:

```
    $platforms = @{
        "epic games"   = "epic"
        "Amazon Games" = "amazon"
        "GOG"          = "gog"
        "Steam"        = "steam"
    }
```

The entries on the left are what would be found in a path, like in *Program Files (x86)*. The entries on the right are what are going to end up in the zip file name as mentioned above. You can of course add and delete platforms from this list. Just maintain the format of the hashtable (I could create a separate config file for platforms but it seems unnecessary). 

**Now Implemented:** script deciding when to make the zip based on modified date. In other words if the source folder has a more recent modified date than the current zip file modified date, a new zip file is made using that date stamp.

It doesn't delete the old zip file though, so I have to either add separate functionality or write a secondary script for finding and deciding what to do with zip files with the same name except for date stamp. Most likely just go with the one with the most recent date stamp.

### 21 October 2024

I found a rather obvious logic bug in my date comparison code today. It turns out I was comparing the folder last modified date to the folder last modified date. Although I was using -lt which is less than, not equal to or less than. So I'm not even sure why it was working in my testing. There's probably a further logic bug there I'm not catching. Using less than with a string type for instance. Is that typecasting to an integer silently so it works? Or am I missing something? 
**Update:** see I couldn't let it go. Ended up type casting any/all 8 digit date codes to actual date objects then using the -lt comparison. I'm glad I went back and did that. String or integer 8 digit date code comparisons would never have worked.

I added a variable to define the date format at the top of the script. Simply change the variable value to your preferred format if (if that isn't month-day-year). Further instructions are in the script comments.

*Anyway* I could probably add some additional polish to this script before starting on jobs. Something involving the *try* keyword. But instead I'll assume I can add that later if needed.

I don't know how many hours I spent on this script today. I'm going to go with "a lot". I tried to start the jobs part of it but made relatively little progress on it. I mean I learned a lot. But the jobs aren't really working.

I added an optional parameter: jobs-enabled. So leave that parameter out and it still has the "normal" functionality (one zip at a time). Or add that parameter and glory in the scripts brokenness. The jobs function is only defined if the parameter is present. I'm sure I'm the first one to figure that out.

It did of course occur to me at some point I don't *have* to try and manager all these zip jobs. I could loop through and slap **&** at the end of the line and try and keep up with displaying status that way. That seems *so much easier* that dealing with start-job.

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

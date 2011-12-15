// jukeboxclient
//
// Author: Fannybaws Tunwarm
// Copyright 2010,2011 - Fannybaws Tunwarm
// This script may be freely copied and modified so long as this header
// remains unmodified.
// 
// v2.0 - Initial upload to github, These infile version details will no longer be updated!
// renamed to jukeboxclient and now using jukeboxserver.php server side

// Globals

// For config file
integer line;
string config_file = "jukeboxclient.config";
key readLineId;

// script user needs to be authorised to use the server, these variables are read from their unique notecard
string url;
string base_path;

// Playing variables
list streams = [];
integer list_length;
list folders_list = [];    
integer folders_list_length;
key http_request_id;
string folder = "";
integer act_title = 0;
integer playing = 0;
integer authorised = 0;

// Setting up some stuff for dialog box
list dialog_choices = [];
string msg = "Please make a choice.";
key ToucherID;
integer channel_dialog;
integer listen_id;

init()
{
    // reset configuration values to default
    url = "Unknown";
    base_path = "Unknown";
 
    // make sure the config file exists and is a notecard
    if(llGetInventoryType(config_file) != INVENTORY_NOTECARD)
    {
        // notify owner of missing file
        llOwnerSay("Missing inventory notecard: " + config_file);
        return; // don't do anything else
    }
 
    // initialize to start reading from first line
    line = 0;
 
    // read the first line
    readLineId = llGetNotecardLine(config_file, line++);
}
processConfiguration(string data)
{
    // if we are at the end of the file
    if(data == EOF)
    {
        // notify the owner
        llOwnerSay("We are done reading the configuration");
 
        // notify what was read
        llOwnerSay("url: " + url);
        llOwnerSay("base_path: " + base_path);
		llOwnerSay("Ready to Rumble, touch me baby!");
 
        // do not do anything else
        return;
    }
 
    // if we are not working with a blank line
    if(data != "")
    {
        // if the line does not begin with a comment
        if(llSubStringIndex(data, "#") != 0)
        {
            // find first equal sign
            integer i = llSubStringIndex(data, "=");
 
            // if line contains equal sign
            if(i != -1)
            {
                // get name of name/value pair
                string name = llGetSubString(data, 0, i - 1);
 
                // get value of name/value pair
                string value = llGetSubString(data, i + 1, -1);
 
                // trim name
                list temp = llParseString2List(name, [" "], []);
                name = llDumpList2String(temp, " ");
 
                // make name lowercase (case insensitive)
                name = llToLower(name);
 
                // trim value
                temp = llParseString2List(value, [" "], []);
                value = llDumpList2String(temp, " ");
 
                // url
                if(name == "url")
                    url = value;
 
                // base_path
                else if(name == "base_path")
                    base_path = value;
 
                // unknown name    
                else
                    llOwnerSay("Unknown configuration value: " + name + " on line " + (string)line);
 
            }
            else  // line does not contain equal sign
            {
                llOwnerSay("Configuration could not be read on line " + (string)line);
            }
        }
    }
 
    // read the next line
    readLineId = llGetNotecardLine(config_file, line++);
 }


// Declare a function to dump a couple of spacer lines
dump_spacers()
{
    llOwnerSay(".");
    llOwnerSay(".");
}

// Declare a function to stop the music
stop_music()
{
    // llSay(0, "Stopping Music");
    llSetTimerEvent(0);
    llSetParcelMusicURL("");
    playing = 0;
}

// Declare a function to dump the playlist
dump_playlist()
{
    dump_spacers();
    llOwnerSay("Current folder is " + folder);
    llOwnerSay((string)(list_length / 3) + " Songs in current playlist:");
    integer count = 0;
    while (count < list_length)
    {
        string this_song = llList2String(streams, count);
        this_song = right(this_song, "!");
        // Is this the current song?
        if (count == act_title)
        {
            this_song = "(Current) " + this_song;
        }
        string this_minutes = llList2String(streams, count + 1);
        string this_seconds = llList2String(streams, count + 2);
        llOwnerSay(this_song + " (" + this_minutes + ":" + this_seconds + ")");
        count += 3;
    }
}

// Declare a function to jump to the next track
next_track()
{
    // llSay(0, "Skipping to next track...");
    llSetTimerEvent(0);
    act_title += 3; // raise the title-counter;
    if(act_title >= list_length)
    { 
        // We reached the end of the list -> start over
        act_title = 0;
    }
    stop_music();
    play_stream();
}

// Declare a function to play the stream
play_stream()
{
    playing = 1;
    string song_url = llList2String(streams, act_title);
    song_url = right(song_url, "!");
    song_url = base_path + folder + "/" + song_url;
    float minutes = llList2Float(streams, act_title + 1);
    float seconds = llList2Float(streams, act_title + 2);
    float time = (minutes * 60) + seconds;
    llSetParcelMusicURL(song_url); // Set the Parcel-Music-Url
    llSetTimerEvent(time);  // Set the Timer-Event to the end of the tune
}

// Function to return string to the right of the our divider in the list("!")
string right(string src, string divider) {
    integer index = llSubStringIndex( src, divider );
    if(~index)
        return llDeleteSubString( src, 0, index + llStringLength(divider) - 1);
    return src;
}

default
{
    state_entry()
    {
		// Try and read the Notecard (jukeboxclient.config)
		init();
        // For dialogue box
        channel_dialog = ( -1 * (integer)("0x"+llGetSubString((string)llGetKey(),-5,-1)) );
    }
	
    on_rez(integer start_param)
    {
		// Try and read the Notecard (jukeboxclient.config)
		init();
        // For dialogue box
        channel_dialog = ( -1 * (integer)("0x"+llGetSubString((string)llGetKey(),-5,-1)) );
    }
    changed(integer change)
    {
        if(change & CHANGED_INVENTORY) init();
    }
    dataserver(key request_id, string data)
    {
        if(request_id == readLineId)
            processConfiguration(data);
 
    }
	
    touch_start(integer total_number)
    {
        // Who touched me?
        ToucherID = llDetectedKey(0);
        
        // Check for owner touch only
        if (llDetectedOwner(0) == llGetOwner())
        {
            // What buttons should we show?
            if (list_length > 1)
            {
                // We have a playlist :)
                // So assume already authorised
                if (playing == 1)
                {
                    dialog_choices = ["Stop"];
                }
                else
                {
                    dialog_choices = ["Play"];
                }
                msg = "Please make your choice";
                dialog_choices = dialog_choices + ["Next", "Playlist", "Reset"];
            }
            else
            {
                // Nothing loaded so lets get the folders
                if (folders_list_length == 0)
                {
                    http_request_id = llHTTPRequest(url + "&list=1", [], "");
                    llOwnerSay("Attempting to connect and load folders, touch me again");
                    // msg = "Attempting to load folders...\nPlease click OK then touch the jukebox again";
                    // dialog_choices = ["OK"];
                }
                else
                {
                    msg = "Please choose a folder to load";
                    dialog_choices = folders_list;
                }
            }
            if (authorised == 1)
            {
                llDialog(ToucherID, msg, dialog_choices, channel_dialog);
                listen_id = llListen( channel_dialog, "", ToucherID, "");
            }
            else
            {
                // Problem with serverkey, we are not authorised so don't do menu
            }
        }
        else
        {
            llInstantMessage(ToucherID, "Sorry, only the owner can use this object");
        }
    }
    
    listen( integer channel, string name, key id, string message )
    {
        // What channel are we on?
        if (channel == channel_dialog)
        {
            if (message == "Stop")
            {
                // Stop music
                stop_music();
            }
            else if (message == "Next")
            {
                // Next track
                next_track();
            }
            else if (message == "Play")
            {
                // Play it
                play_stream();
            }
            else if (message == "Playlist")
            {
                // Dump the Playlist
                dump_playlist();
            }
            else if (message == "OK")
            {
                // Ignore this - its the first instance of touch with nothing loaded, folders are still loading
            }
            else if (message == "Reset")
            {
                // Reset the script (to allow loading new folder)
                llOwnerSay("Reset Clicked, touch again for updated folder list");
                stop_music();
                llResetScript();
                
            }
            else
            {
                // If we get here it must be a folder?
                
                llOwnerSay("Looking for " + message + " folder");
                llOwnerSay(url + "&folder=" + message);
                folder = message;
                http_request_id = llHTTPRequest(url + "&folder=" + message, [], "");
                
            }
        }
    }

    // Now for the timer
    timer()
    {
        // dump_spacers();
        next_track();
    }

    http_response(key request_id, integer status, list metadata, string body)
    {
        if (request_id == http_request_id)
        {
            if ( llGetSubString(body, 0, 3) == "AUTH" )
            {
                // Invalid or missing serverkey
                llOwnerSay("Sorry, you are not authorised to use this server!");
                authorised = 0;
                return;
            }
            else
            {
                authorised = 1;
            }
        
            // Remove newline characters
            body = (string)llParseString2List( body, ["\\n"], [] );
            if ( llSubStringIndex(body , "No such file or directory") != -1 )
            {
                llOwnerSay("Folder '" + folder + "' not found!");
            }
            else if ( llGetSubString(body, 0, 3) == "LIST" )
            {
                body = llGetSubString(body, 4, -1);
                folders_list = llParseString2List(body,[","],[]);
                folders_list_length = llGetListLength(folders_list);
            }
            else if ( llGetSubString(body, 0, 3) == "FOLD" )
            {
                body = llGetSubString(body, 4, -1);
                // Reset streams list to empty
                streams = [];
                act_title = 0;
                streams = streams + llParseString2List(body,[","],[]);
    
                list_length = llGetListLength(streams);
                llOwnerSay("Setting the playlist...");
                llSetTimerEvent(0);
                play_stream();
            }
            
            else
            {
                llOwnerSay("Unknown Error");
            }
        }
    }
}
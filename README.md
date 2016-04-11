# BlueMO
BlueMO allows you to receive data from Adafruit's Bluefruit boards or RFDuino and translate it into MIDI or OSC.

This project satisfies some very specific personal needs, but might be useful for similar applications. I augmented an electric guitar with some sensors, and then I needed to transmit theit output wirelessly to my Mac without the need of additional hardware. I opted for using an Adafruit's Feather 32u4 Bluefruit LE (https://www.adafruit.com/products/2829) to collect sensor data and send it via Bluetooth LE. (It should also work with an RFDuino microcontroller (http://www.rfduino.com/).) BlueMO is written mostly in swift (my first try at OSX development). It uses some external libraries:

- nRF8001 (https://github.com/MichMich/nRF8001-Swift): Originally intended for interfacing the Adafruit nRF8001 breakout with OSX (and iOS). After some hacking, I made it work with either Adafruit's Feather 32u4 (and possibly other Bluefruits boards as well) and RFDuino.

I am also using Cocoapods to install and manage these libraries:

- OSCKit (https://github.com/256dpi/OSCKit): For sending OSC (http://opensoundcontrol.org/introduction-osc) to other apps
- CocoaAsyncSocket (https://github.com/robbiehanson/CocoaAsyncSocket): Required by OSCKit, autmatically imported by Cocoapods

How to set it up:

BlueMO expects packets of values separated by commas and delimited by the "|" character, so set your microcontroller accordingly. On the Mac side:

- Install Cocoapods (Instructions here:https://guides.cocoapods.org/using/getting-started.html)
- Clone the repository or download the source and unzip
- In Terminal, go to the source directory and run "pod install"
- Instead of opening the project directly with Xcode, also in the terminal run "open BlueMO.xcworkspace"
- Compile, install, run, enjoy.

How to use:

1. Select the name of your Bluefruit/RFDuino, so BlueMO connect to it and not to any device around. BlueMO is meant to be ready to work as soon as it is launched, so it will try to connect as soon as you open the software. Additionally, it will remember all your settings from the previous launch without having to press any save button'. No need to reconfigure anything, just launch and play!

2. Configure your Bluetooth module to send data over Bluetooth using string packages with this format:

    AAA,BBB,CCC,DDD,EEE

Where each character group is a different sensor value (or whatever value you want to send) encoded as 3 HEX digits. This enough to represent the full 10-bit sensor value resolution used by most Arduino-based microcontrollers.
A Bluetooth package can be no longer than 20 chars, so currently it might only be possible to send 5 distinct values. I used HEX as it would require character less than representing 10 bits in decimal (it would require 4 chars for values over 1000). I am planning in improving this implementation in the future, maybe by serializing the data stream in a MIDI-like fashion.

3. BlueMO can translate these values into OSC or MIDI.
For MIDI:
BlueMO will create a virtual MIDI port. Select that port in your software and you'll receive datatrhough it. However you can connect BueMO directly to any MIDI port, for instance, to send control data directly to an external instrument. If BlueMO fails to recognize your MIDI port, please let me know about it.
Pick any of the 16 MIDI channels
Pick a continuous controller (MIDI CC) number for each of your sensor values 

For OSC:
By default, BlueMO will send OSC data to the IP 127.0.0.1, port 6666. You can change these, of course.
You can also edit the routing addresses for each incoming sensor value. Again, every change you make will be saved for you to use at a later time.


If you find this project useful, consider buying Spacebarman's music from iTunes here: https://itunes.apple.com/us/album/si-algun-dia-todo-falla/id585191546

(Spacebarman is my band, of course ;)

JP

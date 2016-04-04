# BlueMO
BlueMO allows you to receive data from Adafruit's Bluefruit boards or RFDuino and translate it into MIDI or OSC.

This project satisfies some very specific personal needs, but might be useful for similar applications. I augmented an electric guitar with some sensors, and then I needed to transmit theit output wirelessly to my Mac without the need of additional hardware. I opted for using an Adafruit's Feather 32u4 Bluefruit LE (https://www.adafruit.com/products/2829) to collect sensor data and send it via Bluetooth LE. (It should also work with an RFDuino microcontroller (http://www.rfduino.com/).) BlueMO is written mostly in swift (my first try at OSX development). It uses some external libraries:

- nRF8001 (https://github.com/MichMich/nRF8001-Swift): Originally intended for interfacing the Adafruit nRF8001 breakout with OSX (and iOS). After some hacking, I made it work with either Adafruit's Feather 32u4 (and possibly other Bluefruits boards as well) and RFDuino.

I am also using Cocoapods to install and manage these libraries:

- OSCKit (https://github.com/256dpi/OSCKit): For sending OSC (http://opensoundcontrol.org/introduction-osc) to other apps
- CocoaAsyncSocket (https://github.com/robbiehanson/CocoaAsyncSocket): Required by OSCKit, autmatically imported by Cocoapods

How to set it up:

- Install Cocoapods (Instructions here:https://guides.cocoapods.org/using/getting-started.html)
- Clone the repository or download the source and unzip
- In Terminal, go to the source directory and run "pod install"
- Instead of opening the project directly with Xcode, also in the terminal run "open BlueMO.xcworkspace"
- Compile, install, run, enjoy.

I will be posting information on this project in my blog at www.jpcarrascal.com.

If you find this project useful, consider buying Spacebarman's music from iTunes here: https://itunes.apple.com/us/album/si-algun-dia-todo-falla/id585191546

(Spacebarman is my band, of course ;)

JP

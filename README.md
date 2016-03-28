# BlueMO
BlueMO allows you to receive data from Adafruit's Bluefruit boards or RFDuino and translate it into MIDI or OSC.

This project obeys very specific personal needs, but might be useful for similar applications. I augmented an electric guitar with some sensors. I needed to transmit the output of these sensors wirelessly to my Mac without the need of additional hardware (besides what is installed in the guitar). I opted for using an Adafruit's Feather 32u4 Bluefruit LE (https://www.adafruit.com/products/2829) to collect sensor data and send it through Bluetooth LE. It should also work with an RFDuino microcontroller (http://www.rfduino.com/). BlueMO is written mostly in swift (my first try at OSX development). It uses some external libraries:

- nRF8001 (https://github.com/MichMich/nRF8001-Swift): Originally intended for interfacing the Adafruit nRF8001 breakout with OSX (and iOS). After some hacking, I made it work with RFDuino.

I am also using Cocoapods to install and manage these libraries:

- OSCKit (https://github.com/256dpi/OSCKit): For sending OSC (http://opensoundcontrol.org/introduction-osc) to other apps
- CocoaAsyncSocket (https://github.com/robbiehanson/CocoaAsyncSocket): Required by OSCKit, autmatically imported by Cocoapods

I will be posting information on this project in my blog at www.jpcarrascal.com.

JP

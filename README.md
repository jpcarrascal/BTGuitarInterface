# BTGuitarInterface
Augmented guitar Bluetooth interface for MacOSX using RFDuino

This project obeys very specific personal needs, but might be useful for similar applications. I augmented an electrig guitar with some sensors. I want to transmit the output of these sensors wirelessly to my Mac without the need of additional hardware (besides what is installed in the guitar). I opted for using an RFDuino (http://www.rfduino.com/) to collect sensor data and send it through Bluetooth LE. BTguitarinterface is mostly written in swift (my first try at it). It uses some external libraries:

- nRF8001 (https://github.com/MichMich/nRF8001): Originally intended for interfacing the Adafruit nRF8001 breakout with OSX (and iOS). After some hacking, I made it work with the RFDuino.

I am also using Cocoapods to install and manage these libraries:

- OSCKit (https://github.com/256dpi/OSCKit): For sending OSC (http://opensoundcontrol.org/introduction-osc) to other apps

I will be posting info on this project in my blog at www.jpcarrascal.com.

JP

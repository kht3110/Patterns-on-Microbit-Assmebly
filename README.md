# **Overview**
This program is to do a light show to encouragement people to have a positive mind every day. This light show is operated on Microbit and based on the library provided by ANU COMP2300/6300 Computer Organization, which are retrieved from 
https://gitlab.cecs.anu.edu.au/u7350717/comp2300-2023-assignment-2/-/blob/main/lib/led.S and 
https://gitlab.cecs.anu.edu.au/u7350717/comp2300-2023-assignment-2/-/blob/main/lib/symbols.S.  
<br>

## **Light Show Idea**
The idea for the light show is from my observation of the surrounding. People are easily upset by some minor incidents. However, they can be easily cheered up as well. My light show is about a person who was sad. After he/she saw the bright sun, he/she turned happy, with a sentence of “Yeah!” There is also a sentence “Have a nice day!” being displayed to cheer whoever sees this light show.
<br>

## **Functions**
The program utilizes three button inputs, namely face button, button A and button B.

Face button is to switch the mode, which are auto version and a scroll version. 

For auto version, the pattern to be shown will change automatically according to the time. When Button A is pressed, the level of brightness is switched, which comes with 5 levels.

For the scroll version, the user can scroll through the message using Button A and B. Button A is for scrolling the message from right to left and Button B is vice versa.  

Users can self-define their own messages by replace the LED to be on and off from line 890-1164 and line 1188-1267.
<br>

## **Demo**
A demo video can be accessed via the link below.

[Demo](https://github.com/kht3110/Patterns-on-Microbit-Assmebly/Demo.mp4)
<br>

Another demo with a different message ("HAPPY FATHER's DAY") can be accessed through this link.

[Demo](https://github.com/kht3110/Patterns-on-Microbit-Assmebly/Demo_Happy_Fathers_Day.mp4)
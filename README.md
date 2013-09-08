A simple paint program that creates animated gifs.

Live Demo
---------

Try it out at http://pixelcycle.appspot.com/


Setting up a Development Environment
------------------------------------

Pixelcycle is written in Dart and Go and runs on App Engine. You will need the Dart Editor
(which includes the Dart SDK) and the Go SDK for App Engine.

In the Dart Editor, choose File -> Open Existing Folder and select the folder containing 
this README file and pubspec.yaml.

The Dart Editor contains an embedded web server that automatically runs the compiler when
you reload the page. To try it out, right-click on web/main.html and choose "Run as JavaScript".
It will open your browser on the correct page. After a few seconds looking at a page with a
broken link, the compiler will finish and PixelCycle will start up with an empty canvas. You
will be able to create an animation but the Save button won't work.

(You can also use Dartium, but that requires editing the main.html file slightly.)

To test loading and saving animations, you will need to run a development instance of App Engine
with a command like this.

  {path-to-sdk}/dev_appserver.py web/app.yaml

Then try it out at http://localhost:8080/. The front page will have a broken link, but other than
that, loading and saving should work.

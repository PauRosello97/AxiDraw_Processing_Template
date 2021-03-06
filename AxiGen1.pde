/*
 AxiGen
 
 Generative art example with AxiDraw
 https://github.com/evil-mad/AxiDraw-Processing
 
 Based on RoboPaint RT: 
 https://github.com/evil-mad/robopaint-rt
*/

import de.looksgood.ani.*;
import processing.serial.*;

// User Settings: 
float MotorSpeed = 4000.0;  // Steps per second, 1500 default

int ServoUpPct = 70;    // Brush UP position, %  (higher number lifts higher). 
int ServoPaintPct = 30;    // Brush DOWN position, %  (higher number lifts higher). 

boolean reverseMotorX = false;
boolean reverseMotorY = false;

int delayAfterRaisingBrush = 300; //ms
int delayAfterLoweringBrush = 300; //ms

//boolean debugMode = true;
boolean debugMode = false;

boolean PaperSizeA4 = true; // true for A4. false for US letter.

// Offscreen buffer images for holding drawn elements, makes redrawing MUCH faster

PGraphics offScreen;

PImage imgMain;         // Primary drawing canvas
PImage imgLocator;      // Cursor crosshairs
PImage imgButtons;      // Text buttons
PImage imgHighlight;
String BackgroundImageName = "background.png"; 
String HelpImageName = "help.png"; 

boolean segmentQueued = false;
PVector queuePt1 = new PVector(-1, -1);
PVector queuePt2 = new PVector(-1, -1);

float MotorStepsPerPixel = 32.1;// Good for 1/16 steps-- standard behavior.
float PixelsPerInch = 63.3; 

// Hardware resolution: 1016 steps per inch @ 50% max resolution
// Horizontal extent in this window frame is 740 px.
// 2032 steps per inch * (11.69 inches (i.e., A4 length)) per 740 px gives 16.05 motor steps per pixel.
// Vertical travel for 8.5 inches should be  (8.5 inches * 2032 steps/inch) / (32.1 steps/px) = 538 px.
// PixelsPerInch is given by (2032 steps/inch) / (32.1 steps/px) = 63.3 pixels per inch

// Positions of screen items

int MousePaperLeft =  30;
int MousePaperRight =  770;
int MousePaperTop =  62;
int MousePaperBottom =  600;

int yBrushRestPositionPixels = 6;

int ServoUp;    // Brush UP position, native units
int ServoPaint;    // Brush DOWN position, native units. 

int MotorMinX;
int MotorMinY;
int MotorMaxX;
int MotorMaxY;

color Black = color(25, 25, 25);  // BLACK
color PenColor = Black;

boolean firstPath;
boolean doSerialConnect = true;
boolean SerialOnline;
Serial myPort;  // Create object from Serial class
int val;        // Data received from the serial port

boolean BrushDown;
boolean BrushDownAtPause;
boolean DrawingPath = false;

int xLocAtPause;
int yLocAtPause;

int MotorX;  // Position of X motor
int MotorY;  // Position of Y motor
int MotorLocatorX;  // Position of motor locator
int MotorLocatorY; 
PVector lastPosition; // Record last encoded position for drawing

boolean forceRedraw;
boolean shiftKeyDown;
boolean keyup = false;
boolean keyright = false;
boolean keyleft = false;
boolean keydown = false;
boolean hKeyDown = false;
int lastButtonUpdateX = 0;
int lastButtonUpdateY = 0;

boolean lastBrushDown_DrawingPath;
int lastX_DrawingPath;
int lastY_DrawingPath;

int NextMoveTime;          //Time we are allowed to begin the next movement (i.e., when the current move will be complete).
int SubsequentWaitTime = -1;    //How long the following movement will take.
int UIMessageExpire;
int raiseBrushStatus;
int lowerBrushStatus;
int moveStatus;
int MoveDestX;
int MoveDestY; 
int PaintDest; 

boolean Paused;

PVector[] ToDoList;  // Queue future events in an array; Coordinate/command
// X-coordinate, Y Coordinate.
// If X-coordinate is negative, that is a non-move command.

int indexDone;    // Index in to-do list of last action performed
int indexDrawn;   // Index in to-do list of last to-do element drawn to screen

// Active buttons

int TextColor = 75;
int LabelColor = 150;
color TextHighLight = Black;
int DefocusColor = 175;

void setupAxiGen() 
{
  Ani.init(this); // Initialize animation library
  Ani.setDefaultEasing(Ani.LINEAR);

  firstPath = true;

  offScreen = createGraphics(800, 631);

  surface.setTitle("AxiTurtle");

  if (PaperSizeA4){
    MousePaperRight = round(MousePaperLeft + PixelsPerInch * 297/25.4);
    MousePaperBottom = round(MousePaperTop + PixelsPerInch * 210/25.4);
  } else {
    MousePaperRight = round(MousePaperLeft + PixelsPerInch * 11.0);
    MousePaperBottom = round(MousePaperTop + PixelsPerInch * 8.5);
  }

  shiftKeyDown = false;

  frameRate(60);  // sets maximum speed only

  MotorMinX = 0;
  MotorMinY = 0;
  MotorMaxX = int(floor(float(MousePaperRight - MousePaperLeft) * MotorStepsPerPixel)) ;
  MotorMaxY = int(floor(float(MousePaperBottom - MousePaperTop) * MotorStepsPerPixel)) ;

  lastPosition = new PVector(-1, -1);

  ServoUp = 7500 + 175 * ServoUpPct;    // Brush UP position, native units
  ServoPaint = 7500 + 175 * ServoPaintPct;   // Brush DOWN position, native units. 

  rectMode(CORNERS);

  MotorX = 0;
  MotorY = 0; 

  ToDoList = new PVector[0];

  //ToDoList = new int[0];
  PVector cmd = new PVector(-35, 0);   // Command code: Go home (0,0)
  ToDoList = (PVector[]) append(ToDoList, cmd); 

  indexDone = -1;    // Index in to-do list of last action performed
  indexDrawn = -1;   // Index in to-do list of last to-do element drawn to screen

  raiseBrushStatus = -1;
  lowerBrushStatus = -1; 
  moveStatus = -1;
  MoveDestX = -1;
  MoveDestY = -1;

  Paused = true;
  BrushDownAtPause = false;

  // Set initial position of indicator at carriage minimum 0,0
  int[] pos = getMotorPixelPos();

  background(255);
  MotorLocatorX = pos[0];
  MotorLocatorY = pos[1];

  NextMoveTime = millis();

  drawToDoList();
  redrawButtons();
  redrawHighlight();
  redrawLocator();
}


void pause()
{
  if (Paused) {
    Paused = false;

    if (BrushDownAtPause) {
      int waitTime = NextMoveTime - millis();
      if (waitTime > 0) { 
        delay (waitTime);  // Wait for prior move to finish:
      }

      if (BrushDown) { 
        raiseBrush();
      }

      waitTime = NextMoveTime - millis();
      if (waitTime > 0) { 
        delay (waitTime);  // Wait for prior move to finish:
      }

      MoveToXY(xLocAtPause, yLocAtPause);

      waitTime = NextMoveTime - millis();
      if (waitTime > 0) { 
        delay (waitTime);  // Wait for prior move to finish:
      }

      lowerBrush();
    }
  } else
  {
    Paused = true;
    //TextColor
    if (BrushDown) {
      BrushDownAtPause = true; 
      raiseBrush();
    } else
      BrushDownAtPause = false;

    xLocAtPause = MotorX;
    yLocAtPause = MotorY;
  }

  redrawButtons();
}

boolean serviceBrush()
{
  // Manage processes of getting paint, water, and cleaning the brush,
  // as well as general lifts and moves.  Ensure that we allow time for the
  // brush to move, and wait respectfully, without local wait loops, to
  // ensure good performance for the artist.

  // Returns true if servicing is still taking place, and false if idle.

  boolean serviceStatus = false;

  int waitTime = NextMoveTime - millis();
  if (waitTime >= 0)
  {
    serviceStatus = true;
    // We still need to wait for *something* to finish!
  } else {
    if (raiseBrushStatus >= 0)
    {
      raiseBrush();
      serviceStatus = true;
    } else if (lowerBrushStatus >= 0)
    {
      lowerBrush();
      serviceStatus = true;
    } else if (moveStatus >= 0) {
      MoveToXY(); // Perform next move, if one is pending.
      serviceStatus = true;
    }
  }
  return serviceStatus;
}


void drawToDoList()
{  
  // Erase all painting on main image background, and draw the existing "ToDo" list
  // on the off-screen buffer.

  int j = ToDoList.length;
  float x1, x2, y1, y2;

  float brightness;
  color white = color(255, 255, 255);

  if ((indexDrawn + 1) < j)
  {

    // Ready the offscreen buffer for drawing onto
    offScreen.beginDraw();

    if (indexDrawn < 0) {

      offScreen.noFill();
      offScreen.strokeWeight(0.5);

      if (PaperSizeA4) {
        offScreen.stroke(128, 128, 255);  // Light Blue: A4
        float rectW = PixelsPerInch * 297/25.4;
        float rectH = PixelsPerInch * 210/25.4;
        offScreen.rect(float(MousePaperLeft), float(MousePaperTop), rectW, rectH);
      } else {   
        offScreen.stroke(255, 128, 128); // Light Red: US Letter
        float rectW = PixelsPerInch * 11.0;
        float rectH = PixelsPerInch * 8.5;
        offScreen.rect(float(MousePaperLeft), float(MousePaperTop), rectW, rectH);
      }
    } else
      offScreen.image(imgMain, 0, 0);

    offScreen.strokeWeight(1); 

    brightness = 0;
    color DoneColor = lerpColor(PenColor, white, brightness);

    brightness = 0.8;
    color ToDoColor = lerpColor(PenColor, white, brightness); 

    x1 = 0;
    y1 = 0;

    boolean virtualPenDown = false;

    int index = 0;
    if (index < 0)
      index = 0;
    while ( index < j)
    {
      PVector toDoItem = ToDoList[index];

      x2 = toDoItem.x;
      y2 = toDoItem.y;

      if (x2 >= 0) {
        if (virtualPenDown)
        {
          if (index < indexDone)
            offScreen.stroke(DoneColor);
          else
            offScreen.stroke(ToDoColor);

          offScreen.line(x1, y1, x2, y2); // Preview lines that are not yet on paper

          x1 = x2;
          y1 = y2;
        } else {
          x1 = x2;
          y1 = y2;
        }
      } else {
        int x3 = -1 * round(x2);
        if (x3 == 30) 
        {
          virtualPenDown = false;
        } else if (x3 == 31) 
        {  
          virtualPenDown = true;
          //println("pen down");
        } else if (x3 == 35) 
        {
          x1 = 0;
          y1 = 0;
        }
      }
      index++;
    }

    offScreen.endDraw();
    imgMain = offScreen.get(0, 0, offScreen.width, offScreen.height);
  }
}


void drawAxiGen() {

  if (debugMode)
  {
    frame.setTitle("AxiGen      " + int(frameRate) + " fps");
  }

  drawToDoList();

  // NON-DRAWING LOOP CHECKS ==========================================

  if (doSerialConnect == false) checkServiceBrush(); 

  checkHighlights();

  // ALL ACTUAL DRAWING ==========================================

  image(imgMain, 0, 0, width, height);    // Draw Background image  (incl. paint paths)
  //image(imgButtons, 0, 0); // Draw buttons image
  image(imgHighlight, 0, 0); // Draw highlight image

  // Draw locator crosshair at xy pos, less crosshair offset
  image(imgLocator, MotorLocatorX-10, MotorLocatorY-15);
  
  if (doSerialConnect)
  {
    // FIRST RUN ONLY:  Connect here, so that 

    doSerialConnect = false;

    scanSerial();

    if (SerialOnline)
    {    
      myPort.write("EM,1,1\r");  //Configure both steppers in 1/16 step mode

      // Configure brush lift servo endpoints and speed
      myPort.write("SC,4," + str(ServoPaint) + "\r");  // Brush DOWN position, for painting
      myPort.write("SC,5," + str(ServoUp) + "\r");  // Brush UP position 

      myPort.write("SC,10,65535\r"); // Set brush raising and lowering speed.

      // Ensure that we actually raise the brush:
      BrushDown = true;  
      raiseBrush();    

      UIMessageExpire = millis() + 5000;
      redrawButtons();
    } else
    { 
      println("Now entering offline simulation mode.\n");

      redrawButtons();
    }
  }
}

void keyPressed(){
  if(keyCode == 32) pause(); 
}

/*
  AxiRT
 
 Real-time painting software for AxiDraw
 https://github.com/evil-mad/AxiDraw-Processing
 
 Based on RoboPaint RT: 
 https://github.com/evil-mad/robopaint-rt
 
 */

import de.looksgood.ani.*;
import processing.serial.*;

import javax.swing.UIManager; 
import javax.swing.JFileChooser; 


// User Settings: 
float MotorSpeed = 2500.0;  // Steps per second, 1500 default

int ServoUpPct = 70;    // Brush UP position, %  (higher number lifts higher). 
int ServoPaintPct = 30;    // Brush DOWN position, %  (higher number lifts higher). 

boolean reverseMotorX = false;
boolean reverseMotorY = false;

int delayAfterRaisingBrush = 300; //ms
int delayAfterLoweringBrush = 300; //ms

int minDist = 4; // Minimum drag distance to record

boolean debugMode = false;


// Offscreen buffer images for holding drawn elements, makes redrawing MUCH faster

PGraphics offScreen;

PImage imgMain;         // Primary drawing canvas
PImage imgLocator;      // Cursor crosshairs
PImage imgButtons;      // Text buttons
PImage imgHighlight;
String BackgroundImageName = "background.png"; 
String HelpImageName = "help.png"; 

boolean segmentQueued = false;
int queuePt1 = -1;
int queuePt2 = -1;

float MotorStepsPerPixel = 16.05;// Good for 1/8 steps-- standard behavior.
float PixelsPerInch = 63.3; 

// Hardware resolution: 1016 steps per inch @ 50% max resolution
// Horizontal extent in this window frame is 740 px.
// 1016 steps per inch * (11.69 inches (i.e., A4 length)) per 740 px gives 16.05 motor steps per pixel.
// Vertical travel for 8.5 inches should be  (8.5 inches * 1016 steps/inch) / (16.05 steps/px) = 538 px.
// PixelsPerInch is given by (1016 steps/inch) / (16.05 steps/px).

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
int lastPosition; // Record last encoded position for drawing

int selectedColor;
int selectedWater;
int highlightedWater;
int highlightedColor; 

boolean recordingGesture;
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

int ToDoList[];  // Queue future events in an integer array; executed when PriorityList is empty.
int indexDone;    // Index in to-do list of last action performed
int indexDrawn;   // Index in to-do list of last to-do element drawn to screen

// Active buttons
PFont font_ML16;
PFont font_CB; // Command button font

int TextColor = 75;
int LabelColor = 150;
color TextHighLight = Black;
int DefocusColor = 175;

SimpleButton brushLabel;
SimpleButton motorLabel;

void setup() 
{
  size(800, 631, FX2D);

  Ani.init(this); // Initialize animation library
  Ani.setDefaultEasing(Ani.LINEAR);

  firstPath = true;

  offScreen = createGraphics(800, 631);

  shiftKeyDown = false;

  frameRate(60);  // sets maximum speed only

  MotorMinX = 0;
  MotorMinY = 0;
  MotorMaxX = int(floor(float(MousePaperRight - MousePaperLeft) * MotorStepsPerPixel)) ;
  MotorMaxY = int(floor(float(MousePaperBottom - MousePaperTop) * MotorStepsPerPixel)) ;

  lastPosition = -1;

  ServoUp = 7500 + 175 * ServoUpPct;    // Brush UP position, native units
  ServoPaint = 7500 + 175 * ServoPaintPct;   // Brush DOWN position, native units. 


  font_ML16  = loadFont("Miso-Light-16.vlw"); 
  font_CB = loadFont("Miso-20.vlw"); 

  UIMessageExpire = millis() + 25000; 

  rectMode(CORNERS);

  MotorX = 0;
  MotorY = 0; 

  ToDoList = new int[0];
  ToDoList = append(ToDoList, -35);  // Command code: Go home (0,0)

  indexDone = -1;    // Index in to-do list of last action performed
  indexDrawn = -1;   // Index in to-do list of last to-do element drawn to screen

  raiseBrushStatus = -1;
  lowerBrushStatus = -1; 
  moveStatus = -1;
  MoveDestX = -1;
  MoveDestY = -1;

  Paused = false;
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
  
  if (Paused)
  {
    Paused = false;


    if (BrushDownAtPause)
    {
      int waitTime = NextMoveTime - millis();
      if (waitTime > 0)
      { 
        delay (waitTime);  // Wait for prior move to finish:
      }

      if (BrushDown) { 
        raiseBrush();
      }

      waitTime = NextMoveTime - millis();
      if (waitTime > 0)
      { 
        delay (waitTime);  // Wait for prior move to finish:
      }

      MoveToXY(xLocAtPause, yLocAtPause);

      waitTime = NextMoveTime - millis();
      if (waitTime > 0)
      { 
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
  int x1, x2, y1, y2;
  int intTemp = -100;

  color interA;
  float brightness;
  color white = color(255, 255, 255);

  if ((indexDrawn + 1) < j)
  {

    // Ready the offscreen buffer for drawing onto
    offScreen.beginDraw();

    if (indexDrawn < 0) {

      offScreen.noFill();
      offScreen.strokeWeight(0.5);
      offScreen.stroke(255, 128, 128);
      float rectW = PixelsPerInch * 11.0;
      float rectH = PixelsPerInch * 8.5;
      offScreen.rect(float(MousePaperLeft), float(MousePaperTop), rectW, rectH);

      offScreen.stroke(128, 128, 255);
      rectW = PixelsPerInch * 297/25.4;
      rectH = PixelsPerInch * 210/25.4;
      offScreen.rect(float(MousePaperLeft), float(MousePaperTop), rectW, rectH);

      // &&&&&
    } else
      offScreen.image(imgMain, 0, 0);


    offScreen.strokeWeight(1); 

    offScreen.stroke(PenColor);

    x1 = 0;
    y1 = 0;

    while ( (indexDrawn + 1) < j) {

      indexDrawn++;  
      // NOTE:  We increment the "Drawn" count here at the beginning of the loop,
      //        momentarily indicating (somewhat inaccurately) that the so-numbered
      //        list element has been drawn-- really, we're in the process of drawing it,
      //        and everything will be back to accurate once we're outside of the loop.


      intTemp = ToDoList[indexDrawn];

      if (intTemp >= 0)
      {  // Preview a path segment

        x2 = floor(intTemp / 10000);
        y2 = intTemp - 10000 * x2; 

        if (DrawingPath)
          if ((x1 + y1) == 0)    // first time through the loop
          {
            intTemp = ToDoList[indexDrawn - 1];
            if (intTemp >= 0)
            {  // first point on this segment can be taken from history!

              x1 = floor(intTemp / 10000);
              y1 = intTemp - 10000 * x1;
            }
          }

        if (DrawingPath == false) {  // Just starting a new path
          DrawingPath = true;
          x1 = x2;
          y1 = y2;
        }

        brightness = 0.85;
        interA = lerpColor(PenColor, white, brightness);  //To-do items in queue

        offScreen.stroke(interA);
        offScreen.line(x1, y1, x2, y2); 

        x1 = x2;
        y1 = y2;
      } else
      {    // intTemp < 0, so we are doing something else.
        intTemp = -1 * intTemp;
        DrawingPath = false;

        if ((intTemp > 9) && (intTemp < 20)) 
        {  // Change paint color 
          intTemp -= 10;
        } else if (intTemp == 30) 
        {  
          lastBrushDown_DrawingPath = false;
        } else if (intTemp == 31) 
        {  // Lower brush
          lastBrushDown_DrawingPath = true;
        }
      }
    }

    offScreen.endDraw();

    imgMain = offScreen.get(0, 0, offScreen.width, offScreen.height);
  }
}

void queueSegmentToDraw(int prevPoint, int newPoint)
{
  segmentQueued = true;
  queuePt1 = prevPoint;
  queuePt2 = newPoint;
}

void drawQueuedSegment()
{    // Draw new "done" segment, on the off-screen buffer.

  int x1, x2, y1, y2;  
  color interA;
  float brightness;

  if (segmentQueued)
  {
    segmentQueued = false;

    offScreen.beginDraw();     // Ready the offscreen buffer for drawing
    offScreen.image(imgMain, 0, 0);
    offScreen.strokeWeight(1); 

    interA = PenColor;

    brightness = 0.25;
    color white = color(255, 255, 255);
    interA = lerpColor(interA, white, brightness);

    offScreen.stroke(interA);  // Show paths that are already printed on the paper.

    x1 = floor(queuePt1 / 10000);
    y1 = queuePt1 - 10000 * x1;

    x2 = floor(queuePt2 / 10000);
    y2 = queuePt2 - 10000 * x2;  

    offScreen.line(x1, y1, x2, y2); 

    offScreen.endDraw();

    imgMain = offScreen.get(0, 0, offScreen.width, offScreen.height);
  }
}

void cosesInDraw(){

  drawToDoList();

  // NON-DRAWING LOOP CHECKS ==========================================

  if (doSerialConnect == false)
    checkServiceBrush(); 

  checkHighlights();

  // ALL ACTUAL DRAWING ==========================================

  if  (hKeyDown)
  {  // Help display
    image(loadImage(HelpImageName), 0, 0, 800, 631);
  } else
  {
    image(imgMain, 0, 0, width, height);    // Draw Background image  (incl. paint paths)
    image(imgButtons, 0, 0);
    image(imgHighlight, 0, 0);
    image(imgLocator, MotorLocatorX-10, MotorLocatorY-15);
  }

  if (doSerialConnect)
  {
    doSerialConnect = false;

    scanSerial();

    if (SerialOnline)
    {    
      myPort.write("EM,2\r");  //Configure both steppers to 1/8 step mode

      // Configure brush lift servo endpoints and speed
      myPort.write("SC,4," + str(ServoPaint) + "\r");  // Brush DOWN position, for painting
      myPort.write("SC,5," + str(ServoUp) + "\r");  // Brush UP position 
      myPort.write("SC,10,65535\r"); // Set brush raising and lowering speed.

      // Ensure that we actually raise the brush:
      BrushDown = true;  
      raiseBrush();    

      UIMessageExpire = millis() + 5000;
      println("Now entering interactive painting mode.\n");
      redrawButtons();
    } else
    { 
      println("Now entering offline simulation mode.\n");

      UIMessageExpire = millis() + 5000;
      redrawButtons();
    }
  }
  
}

void draw() {
  background(255);
  cosesInDraw();
}

// Only need to redraw if hovering or changing state
void redrawButtons() {
  offScreen.beginDraw();
  offScreen.background(0, 0);

  DrawButtons(offScreen);

  offScreen.endDraw();

  imgButtons = offScreen.get(0, 0, offScreen.width, offScreen.height);
}

// Only need to redraw if hovering or change select on specific items
void redrawHighlight() {
  offScreen.beginDraw();
  offScreen.background(0, 0);

  offScreen.endDraw();
  imgHighlight = offScreen.get(0, 0, offScreen.width, offScreen.height);

  // TODO: Remove this section?
}

// Draw the locator crosshair to the offscreen buffer and fill imgLocator with it
// Only need to redraw this when it changes color
void redrawLocator() {
  offScreen.beginDraw();
  offScreen.background(0, 0);

  offScreen.stroke(0, 0, 0, 128); 
  offScreen.strokeWeight(2);  
  int x0 = 10;
  int y0 = 10; 

  if (BrushDown)
    offScreen.fill(PenColor);
  else
    offScreen.noFill();

  offScreen.ellipse(x0, y0, 10, 10);

  offScreen.line(x0 + 5, y0, x0 + 10, y0);
  offScreen.line(x0 - 5, y0, x0 - 10, y0);
  offScreen.line(x0, y0 + 5, x0, y0 + 10);
  offScreen.line(x0, y0 - 5, x0, y0 - 10);
  offScreen.endDraw();

  imgLocator = offScreen.get(0, 0, 25, 25);
}

void mousePressed() {
  customMoveTo(mouseX, mouseY);
}

void customMoveTo(float x, float y){
  boolean doHighlightRedraw = false;

  //The mouse button was just pressed!  Let's see where the user clicked!

  if ((mouseX >= MousePaperLeft) && (mouseX <= MousePaperRight) && (mouseY >= MousePaperTop) && (mouseY <= MousePaperBottom))
  {  // Begin recording gesture   // Over paper!
    recordingGesture = true;

    ToDoList = append(ToDoList, -30);   // Command Code:  -30 (raise brush)  (Only has an effect if the brush is already down.)
    ToDoList = append(ToDoList, xyEncodeInt2(x, y));    // Command Code: Move to first (X,Y) point
    ToDoList = append(ToDoList, -31);              // Command Code:  -31 (lower brush)
    
    redrawLocator();
    redrawHighlight();
  }
}


void SavefileSelected(File selection) {    // SAVE FILE
  if (selection == null) {
    // If a file was not selected
    println("No output file was selected...");
    //       ErrorDisplay = "ERROR: NO FILE NAME CHOSEN.";

    UIMessageExpire = millis() + 3000;
  } else { 

    String[] FileOutput; 
    //        String rowTemp;

    String savePath = selection.getAbsolutePath();
    String[] p = splitTokens(savePath, ".");
    boolean fileOK = false;

    FileOutput = new String[0];

    if ( p[p.length - 1].equals("RRT"))
      fileOK = true;
    if ( p[p.length - 1].equals("rrt"))
      fileOK = true;      
    if (fileOK == false)
      savePath = savePath + ".rrt";

    // If a file was selected, print path to folder 
    println("Save file: " + savePath); 

    int listLength = ToDoList.length; 
    for ( int i = 0; i < listLength; ++i) {

      FileOutput = append(FileOutput, str(ToDoList[i]));
    } 

    saveStrings(savePath, FileOutput);

    UIMessageExpire = millis() + 3000;

  }
}

void fileSelected(File selection) {    // LOAD (OPEN) FILE
  if (selection == null) {
    println("Window was closed or the user hit cancel.");

    UIMessageExpire = millis() + 3000;
  } else {
    //println("User selected " + selection.getAbsolutePath());

    String loadPath = selection.getAbsolutePath();

    // If a file was selected, print path to file 
    println("Loaded file: " + loadPath); 

    String[] p = splitTokens(loadPath, ".");
    boolean fileOK = false;
    int todoNew;

    if ( p[p.length - 1].equals("RRT"))
      fileOK = true;
    if ( p[p.length - 1].equals("rrt"))
      fileOK = true;      

    println("File OK: " + fileOK); 

    if (fileOK) {

      String lines[] = loadStrings(loadPath);

      Paused = false;
      pause();

      // Clear indexDone to "zero" (actually, -1, since even element 0 is not "done.")   & redraw to-do list.

      ToDoList = new int[0];   
      indexDone = -1;    // Index in to-do list of last action performed
      indexDrawn = -1;   // Index in to-do list of last to-do element drawn to screen

      drawToDoList();

      println("there are " + lines.length + " lines");
      for (int i = 0; i < lines.length; i++) { 
        todoNew = parseInt(lines[i]);
        //        println(str(todoNew));
        ToDoList = append(ToDoList, todoNew);
      }
    } else {
      // Can't load file
      //      ErrorDisplay = "ERROR: BAD FILE TYPE";
    }
  }
}


void mouseDragged() { 

  int i;
  int posOld, posNew;

  boolean addpoint = false;
  float distTemp = 0;

  if (recordingGesture)
  { 
    posNew = xyEncodeInt2();

    i = ToDoList.length; 

    if (i > 1)
    {
      posOld = ToDoList[i - 1];

      if (posOld != posNew) {  // Avoid adding duplicate points to ToDoList!

        addpoint = true;
        distTemp = getDistance(posOld, posNew) ;
        // Only add points that are some minimum distance away from each other 
        if (distTemp < minDist) {  
          addpoint = false;
        }  

        if (addpoint)
          ToDoList = append(ToDoList, posNew);  // Command code: XY coordinate pair
      }
    } else
    { // List length may be zero. 
      ToDoList = append(ToDoList, posNew);  // Command code: XY coordinate pair
    }
  }
}


void mouseReleased() {
  if (recordingGesture)
  {   
    recordingGesture = false; 
    ToDoList = append(ToDoList, -30);   // Command Code:  -30 (raise brush)
  }
}


void keyReleased()
{

  if (key == CODED) {

    if (keyCode == UP) keyup = false; 
    if (keyCode == DOWN) keydown = false; 
    if (keyCode == LEFT) keyleft = false; 
    if (keyCode == RIGHT) keyright = false; 

    if (keyCode == SHIFT) { 

      shiftKeyDown = false;
    }
  } else
    key = Character.toLowerCase(key);

  if ( key == 'h')  // display help
  {
    hKeyDown = false;
  }
}



void keyPressed()
{

  //String keyString = new String({key});

  //  keyString.toLowerCase();
  //key = keyString.charAt(0);


  if (key == CODED) {

    // Arrow keys are used for nudging, with or without shift key.

    if (keyCode == UP) 
    {
      keyup = true;
    }
    if (keyCode == DOWN)
    { 
      keydown = true;
    }
    if (keyCode == LEFT) keyleft = true; 
    if (keyCode == RIGHT) keyright = true; 
    if (keyCode == SHIFT) shiftKeyDown = true;
  } else
  {
    key = Character.toLowerCase(key);
    println("Key pressed" + key); 

    if ( key == 'b')   // Toggle brush up or brush down with 'b' key
    {
      if (BrushDown)
        raiseBrush();
      else
        lowerBrush();
    }

    if ( key == 'z')  // Zero motor coordinates
      zero();

    if ( key == ' ')  //Space bar: Pause
      pause();

    if ( key == 'q')  // Move home (0,0)
    {
      raiseBrush();
      MoveToXY(0, 0);
    }

    if ( key == 'h')  // display help
    {
      hKeyDown = true;
      println("HELP requested");
    } 

    if ( key == 't')  // Disable motors, to manually move carriage.  
      MotorsOff();

    if ( key == '1')
      MotorSpeed = 500;  
    if ( key == '2')
      MotorSpeed = 1000;        
    if ( key == '3')
      MotorSpeed = 1500;        
    if ( key == '4')
      MotorSpeed = 2000;        
    if ( key == '5')
      MotorSpeed = 2500;        
    if ( key == '6')
      MotorSpeed = 2900;        
    if ( key == '7')
      MotorSpeed = 3200;        
    if ( key == '8')
      MotorSpeed = 3500;        
    if ( key == '9')
      MotorSpeed = 4000;
  }
}

////////////////////////////////////////////////////
//                                                //
//    W_MyNewWidget.pde                           //
//    Enums can be found in FocusEnums.pde        //
//                                                //
//                                                //
//    Created by: Jiayi Zhou 2023                 //
//                                                //
////////////////////////////////////////////////////

/*
 * To-Do Lists:
 * 1. need three classes to identify: no hands are moving, moving left hand only, moving right hand only
 *    currently our model only supports two, i.e., moving left hand and moving right hand
 * 2. need to figure out how to parse the output from our models
 *    i.e., at least should have 1 numeric value that indicates one of the three classes
 *    and also need to have its corresponding time value (must or better to have?) to plot the graph
 * 3. integrate models into brainflow library, generate our own dynamic library and load from it (doable?)
 */

/* Beginning of copy */
import org.apache.commons.lang3.ArrayUtils;
import org.apache.commons.lang3.tuple.Pair;

// import machine learning and EEG data processing libraries
import brainflow.BoardIds;
import brainflow.BoardShim;
import brainflow.BrainFlowClassifiers;
import brainflow.BrainFlowInputParams;
import brainflow.BrainFlowMetrics;
import brainflow.BrainFlowModelParams;
import brainflow.DataFilter;
import brainflow.LogLevels;
import brainflow.MLModel;
/* End of copy */

import java.util.Random;

// global bool to indicate which model is performing now
private boolean hands = false;
private boolean stimulations = false;

class W_MyNewWidget extends Widget {

    // to see all core variables/methods of the Widget class, refer to Widget.pde
    // put your custom variables here...

    /* Beginning of copy */
    //private ChannelSelect myNewChanSelect;
    //private boolean prevChanSelectIsVisible = false;
    //private AuditoryNeurofeedback auditoryNeurofeedback;
    private Grid dataGrid;
    private final int NUM_TABLE_ROWS = 1;   // constant
    private final int NUM_TABLE_COLUMNS = 2;
    private int tableHeight = 0;
    private int cellHeight = 10;
    private DecimalFormat df = new DecimalFormat("#.0000");
    private final int PAD_FIVE = 5;
    private final int PAD_TWO = 2;
    private final int METRIC_DROPDOWN_W = 100;
    //private final int CLASSIFIER_DROPDOWN_W = 80;
    private myFocusBar focusBar;
    private float focusBarHardYAxisLimit = 1.05f; // provide slight "breathing room" to avoid GPlot error when metric value == 1.0
    private FocusXLim xLimit = FocusXLim.TEN;
    private MyMetric focusMetric = MyMetric.MOVEMENT;
    //private FocusClassifier focusClassifier = FocusClassifier.REGRESSION;
    private FocusThreshold focusThreshold = FocusThreshold.FIVE_TENTHS;
    private FocusColors focusColors = FocusColors.ORANGE;
    private int[] exgChannels;
    private int channelCount;
    private double[][] dataArray;
    //private MLModel mlModel;
    private double metricPrediction = 0d;
    private boolean predictionExceedsThreshold = false;
    private float xc, yc, wc, hc; // status circle center xy, width and height
    private int graphX, graphY, graphW, graphH;
    private final int GRAPH_PADDING = 30;
    private color cBack, cDark, cMark, cFocus, cWave, cPanel;
    List<controlP5.Controller> cp5ElementsToCheck = new ArrayList<controlP5.Controller>();
    /* End of copy */

    ControlP5 localCP5;
    Button motorModelButton;
    Button p300ModelButton;
    private boolean leftHand = false;

    // the constructor initializes the widget
    W_MyNewWidget(PApplet _parent) {
        super(_parent); // calls the parent CONSTRUCTOR method of Widget (DON'T REMOVE)
        
        // This is the protocol for setting up dropdowns.
        // Note that these 3 dropdowns correspond to the 3 global functions below
        // You just need to make sure the "id" (the 1st String) has the same name as the corresponding function
        /*addDropdown("Test1", "Drop 1", Arrays.asList("A", "B"), 0);
        addDropdown("Test2", "Drop 2", Arrays.asList("C", "D", "E"), 1);
        addDropdown("Test3", "Drop 3", Arrays.asList("F", "G", "H", "I"), 3);*/

        /* Beginning of copy */
        // Add channel select dropdown to this widget
        //myNewChanSelect = new ChannelSelect(pApplet, this, x, y, w, navH, "MyNewWidgetChannelSelect");
        //myNewChanSelect.activateAllButtons();
        //cp5ElementsToCheck.addAll(myNewChanSelect.getCp5ElementsForOverlapCheck());

        //auditoryNeurofeedback = new AuditoryNeurofeedback(x + PAD_FIVE, y + PAD_FIVE, w/2 - PAD_FIVE*2, navBarHeight/2);
        //cp5ElementsToCheck.add((controlP5.Controller)auditoryNeurofeedback.startStopButton);
        //cp5ElementsToCheck.add((controlP5.Controller)auditoryNeurofeedback.modeButton);

        //exgChannels = currentBoard.getEXGChannels();
        //channelCount = currentBoard.getNumEXGChannels();
        //dataArray = new double[channelCount][];

        // initialize graphics parameters
        onColorChange();
        
        // This is the protocol for setting up dropdowns
        dropdownWidth = 60; // Override the default dropdown width for this widget
        //addDropdown("myFocusMetricDropdown", "Metric", Arrays.asList("Movement", "Stimulation"), 0);
        addDropdown("myFocusMetricDropdown", "Metric", focusMetric.getEnumStringsAsList(), focusMetric.getIndex());
        //addDropdown("myFocusClassifierDropdown", "Classifier", focusClassifier.getEnumStringsAsList(), focusClassifier.getIndex());
        addDropdown("myFocusThresholdDropdown", "Threshold", focusThreshold.getEnumStringsAsList(), focusThreshold.getIndex());
        addDropdown("myFocusWindowDropdown", "Window", xLimit.getEnumStringsAsList(), xLimit.getIndex());
        //addDropdown("SpectrogramMaxFreq", "Max Freq", Arrays.asList(settings.spectMaxFrqArray), settings.spectMaxFrqSave);
        
        // Create data table
        dataGrid = new Grid(NUM_TABLE_ROWS, NUM_TABLE_COLUMNS, cellHeight);
        dataGrid.setTableFontAndSize(p5, 12);
        dataGrid.setDrawTableBorder(true);
        dataGrid.setString("Confidence Score", 0, 0);
        //dataGrid.setString("Delta (0.5-4Hz)", 1, 0);
        //dataGrid.setString("Theta (4-8Hz)", 2, 0);
        //dataGrid.setString("Alpha (8-13Hz)", 3, 0);
        //dataGrid.setString("Beta (13-32Hz)", 4, 0);
        //dataGrid.setString("Gamma (32-100Hz)", 5, 0);

        //create our focus graph
        updateGraphDims();
        focusBar = new myFocusBar(_parent, xLimit.getValue(), focusBarHardYAxisLimit, graphX, graphY, graphW, graphH);

        //initBrainFlowMetric();
        /* End of copy */

        // Instantiate local cp5 for this box. This allows extra control of drawing cp5 elements specifically inside this class.
        localCP5 = new ControlP5(ourApplet);
        localCP5.setGraphics(ourApplet, 0,0);   // sets the origin point for rendering, 0,0 is the top-left corner
        localCP5.setAutoDraw(false);

        createMotorModelButton();
        createP300ModelButton();
       
    }

    // refreshes UI elements and updates the metric
    public void update() {
        super.update(); //calls the parent update() method of Widget (DON'T REMOVE)

        //put your code here...

        /* Beginning of copy */
        //Update channel checkboxes and active channels
        //myNewChanSelect.update(x, y, w);

        //Flex the Gplot graph when channel select dropdown is open/closed
        /*if (myNewChanSelect.isVisible() != prevChanSelectIsVisible) {
            channelSelectFlexWidgetUI();
            prevChanSelectIsVisible = myNewChanSelect.isVisible();
        }*/

        //channelSelectFlexWidgetUI();

        // upon the app is streaming data
        if (currentBoard.isStreaming()) {
            dataGrid.setString(df.format(metricPrediction), 0, 1);
            focusBar.update(metricPrediction);
        }
        
        //lockElementsOnOverlapCheck(cp5ElementsToCheck);
        /* End of copy */
    }

    // handles the rendering of the widget
    public void draw() {
        super.draw(); //calls the parent draw() method of Widget (DON'T REMOVE)

        /* Beginning of copy */
        // draw data table
        dataGrid.draw();

        // draw focus circle
        drawStatusCircle();

        /* if (false) {
            //Draw some guides to help develop this widget faster
            pushStyle();
            stroke(OPENBCI_DARKBLUE);
            //Main guides
            line(x, y+(h/2), x+w, y+(h/2));
            line(x+(w/2), y, x+(w/2), y+(h/2));
            //Top left container center
            line(x+(w/4), y, x+(w/4), y+(h/2));
            line(x, y+(h/4), x+(w/2), y+(h/4));
            popStyle();
        }*/

        //auditoryNeurofeedback.draw();
        
        // draw the graph
        focusBar.draw();

        //myNewChanSelect.draw();
        /* End of copy */

        //remember to refer to x,y,w,h which are the positioning variables of the Widget class

        // This draws all cp5 objects in the local instance
        // e.g., all the clickable buttons
        localCP5.draw();
    }

    // handles screen resizing
    public void screenResized() {
        super.screenResized(); //calls the parent screenResized() method of Widget (DON'T REMOVE)

        // Very important to allow users to interact with objects after app resize        
        localCP5.setGraphics(ourApplet, 0, 0);

        /* Beginning of copy */

        // resize the data table
        resizeTable();

        // resize the focus circle
        updateStatusCircle();

        //updateAuditoryNeurofeedbackPosition();

        // resize the graph
        updateGraphDims();
        focusBar.screenResized(graphX, graphY, graphW, graphH);

        //myNewChanSelect.screenResized(pApplet);

        // Custom resize these dropdowns due to longer text strings as options
        cp5_widget.get(ScrollableList.class, "myFocusMetricDropdown").setWidth(METRIC_DROPDOWN_W);
        cp5_widget.get(ScrollableList.class, "myFocusMetricDropdown").setPosition(
            x0 + w0 - (dropdownWidth*2) - METRIC_DROPDOWN_W /*- CLASSIFIER_DROPDOWN_W*/ - (PAD_TWO*4), 
            navH + y0 + PAD_TWO
            );
        /*cp5_widget.get(ScrollableList.class, "myFocusClassifierDropdown").setWidth(CLASSIFIER_DROPDOWN_W);
        cp5_widget.get(ScrollableList.class, "myFocusClassifierDropdown").setPosition(
            x0 + w0 - (dropdownWidth*2) - CLASSIFIER_DROPDOWN_W - (PAD_TWO*3), 
            navH + y0 + PAD_TWO
            );*/
        /* End of copy */

        // We need to set the position of our Cp5 object after the screen is resized
        float upperLeftContainerH = h/2;
        int top = y + PAD_FIVE + int(upperLeftContainerH - PAD_FIVE*2)/3*2;
        int temp = int(w*0.75);
        motorModelButton.setPosition(x + temp - PAD_FIVE*20, top - motorModelButton.getHeight()/2);
        p300ModelButton.setPosition(x + temp - PAD_FIVE*20, top - p300ModelButton.getHeight()/2 + p300ModelButton.getHeight() + PAD_FIVE);

    }

    // handles user interactions, e.g., mouse click
    public void mousePressed() {
        super.mousePressed(); //calls the parent mousePressed() method of Widget (DON'T REMOVE)
        //Since GUI v5, these methods should not really be used.
        //Instead, use ControlP5 objects and callbacks. 
        //Example: createWidgetTemplateButton() found below
        /* Beginning of copy */
        //myNewChanSelect.mousePressed(this.dropdownIsActive); //Calls channel select mousePressed and checks if clicked
        /* End of copy */
    }

    // handles user interactions, e.g., mouse release
    public void mouseReleased() {
        super.mouseReleased(); //calls the parent mouseReleased() method of Widget (DON'T REMOVE)
        //Since GUI v5, these methods should not really be used.
    }

    // When creating new UI objects, follow this rough pattern.
    // Using custom methods like this allows us to condense the code required to create new objects.
    // You can find more detailed examples in the Control Panel, where there are many UI objects with varying functionality.
    private void createMotorModelButton() {
        //This is a generalized createButton method that allows us to save code by using a few patterns and method overloading
        motorModelButton = createButton(localCP5, "motorModelButton", "Motor Model", x + w/2, y + h/2, 200, navHeight, p4, 14, colorNotPressed, OPENBCI_DARKBLUE);
        //Set the border color explicitely
        motorModelButton.setBorderColor(OBJECT_BORDER_GREY);
        //For this button, only call the callback listener on mouse release
        motorModelButton.onRelease(new CallbackListener() {
            public void controlEvent(CallbackEvent theEvent) {
                //If using a TopNav object, ignore interaction with widget object (ex. widgetTemplateButton)
                if (!topNav.configSelector.isVisible && !topNav.layoutSelector.isVisible) {
                    openURLInBrowser("https://drive.google.com/drive/folders/1zvqiY50xJSQdjj9FDotUKfD_4f3fqcU9");
                }
            }
        });
        motorModelButton.setDescription("Click to redirect to our motor model.");
    }

    private void createP300ModelButton() {
        //This is a generalized createButton method that allows us to save code by using a few patterns and method overloading
        p300ModelButton = createButton(localCP5, "p300ModelButton", "P300 Model", x + w/2, y + h/2, 200, navHeight, p4, 14, colorNotPressed, OPENBCI_DARKBLUE);
        //Set the border color explicitely
        p300ModelButton.setBorderColor(OBJECT_BORDER_GREY);
        //For this button, only call the callback listener on mouse release
        p300ModelButton.onRelease(new CallbackListener() {
            public void controlEvent(CallbackEvent theEvent) {
                //If using a TopNav object, ignore interaction with widget object (ex. widgetTemplateButton)
                if (!topNav.configSelector.isVisible && !topNav.layoutSelector.isVisible) {
                    openURLInBrowser("https://drive.google.com/drive/folders/1zvqiY50xJSQdjj9FDotUKfD_4f3fqcU9");
                }
            }
        });
        p300ModelButton.setDescription("Click to redirect to our P300 model.");
    }

    // add custom functions here
    //private void customFunction() {
        //this is a fake function... replace it with something relevant to this widget

    //}

    /* Beginning of copy */
    private void resizeTable() {
        //int extraPadding = myNewChanSelect.isVisible() ? navHeight : 0;
        float upperLeftContainerW = w/2;
        float upperLeftContainerH = h/2;
        //float min = min(upperLeftContainerW, upperLeftContainerH);
        int tx = x + int(upperLeftContainerW);
        int ty = y + PAD_FIVE + int(upperLeftContainerH - PAD_FIVE*2)/3 /* + extraPadding*/;
        int tw = int(upperLeftContainerW) - PAD_FIVE*2;
        //tableHeight = tw;
        dataGrid.setDim(tx, ty, tw);
        dataGrid.setTableHeight(int(upperLeftContainerH - PAD_FIVE*2)/6);
        dataGrid.dynamicallySetTextVerticalPadding(0, 0);
        dataGrid.setHorizontalCenterTextInCells(true);
    }

    //private void updateAuditoryNeurofeedbackPosition() {
    //    int extraPadding = myNewChanSelect.isVisible() ? navHeight : 0;
    //    int subContainerMiddleX = x + w/4;
    //    auditoryNeurofeedback.screenResized(subContainerMiddleX, (int)(y + h/2 - navHeight + extraPadding), w/2 - PAD_FIVE*2, navBarHeight/2);
    //}

    private void updateStatusCircle() {
        float upperLeftContainerW = w/2;
        float upperLeftContainerH = h/2;
        float min = min(upperLeftContainerW, upperLeftContainerH);
        xc = x + w/4;
        yc = y + h/4 - navHeight;
        wc = min * (3f/5);
        hc = wc;
    }

    private void updateGraphDims() {
        graphW = int(w - PAD_FIVE*4);
        graphH = int(h/2 - GRAPH_PADDING - PAD_FIVE*2);
        graphX = x + PAD_FIVE*2;
        graphY = int(y + h/2);
    }

    // core method to fetch and process data
    // returns a metric value from 0. to 1. When there is an error, returns -1.
    // computes metric using EEG data, leveraging the BrainFlow library for data processing and analysis
    private double updateFocusState() {
        /*try {
            int windowSize = currentBoard.getSampleRate() * xLimit.getValue();
            // getData in GUI returns data in shape ndatapoints x nchannels, in BrainFlow its transposed
            List<double[]> currentData = currentBoard.getData(windowSize);

            if (currentData.size() != windowSize || myNewChanSelect.activeChan.size() <= 0) {
                return -1.0;
            }

            for (int i = 0; i < channelCount; i++) {
                dataArray[i] = new double[windowSize];
                for (int j = 0; j < currentData.size(); j++) {
                    dataArray[i][j] = currentData.get(j)[exgChannels[i]];
                }
            }

            int[] channelsInDataArray = ArrayUtils.toPrimitive(
                    myNewChanSelect.activeChan.toArray(
                        new Integer[myNewChanSelect.activeChan.size()]
                    ));

            //Full Source Code for this method: https://github.com/brainflow-dev/brainflow/blob/c5f0ad86683e6eab556e30965befb7c93e389a3b/src/data_handler/data_handler.cpp#L1115
            Pair<double[], double[]> bands = DataFilter.get_avg_band_powers (dataArray, channelsInDataArray, currentBoard.getSampleRate(), true);
            double[] featureVector = bands.getLeft ();

            //Left array is Averages, right array is Standard Deviations. Update values using Averages.
            updateBandPowerTableValues(bands.getLeft());

            //Keep this here
            double prediction = mlModel.predict(featureVector)[0];
            //println("Concentration: " + prediction);

            //Send band power and prediction data to AuditoryNeurofeedback class
            //auditoryNeurofeedback.update(bands.getLeft(), (float)prediction);
            
            return prediction;

        } catch (BrainFlowError e) {
            e.printStackTrace();
            println("Error updating focus state!");
            return -1d;
        }*/
        if (currentBoard.isStreaming()) {
            double random_number = 0.75 + (Math.random() * 0.25);

            /*long seed = 12345;
            Random random_generator = new Random(seed);
            double random_number = 0.75 + random_generator.nextDouble() * 0.25;*/

            int delay = 50; // number of milliseconds to sleep
            long start = System.currentTimeMillis();
            while(start >= System.currentTimeMillis() - delay); // do nothing

            return random_number;
        } else {
            return -1d;
        }
    }

    /*private void updateBandPowerTableValues(double[] bandPowers) {
        for (int i = 0; i < bandPowers.length; i++) {
            dataGrid.setString(df.format(bandPowers[i]), 1 + i, 1);
        }
    }*/

    private void drawStatusCircle() {
        color fillColor;
        color strokeColor;
        StringBuilder sb = new StringBuilder("");
        if (predictionExceedsThreshold) {
            fillColor = cFocus;
            strokeColor = cFocus;
            sb.append(focusMetric.getIdealStateString());
            if (hands && !stimulations) {
                if(leftHand) {
                    sb.append(" Left Hand");
                } else {
                    sb.append(" Right Hand");
                }
            }
        } else {
            fillColor = cDark;
            strokeColor = cDark;
            if (hands && !stimulations) {
                sb.append("No Hands Moving");
            } else if (!hands && stimulations) {
                sb.append("No Stimulations");
            } else {
                sb.append("No Hands Moving");
            }
        }
        //sb.append(focusMetric.getIdealStateString());
        //Draw status graphic
        pushStyle();
        noStroke();
        fill(fillColor);
        stroke(strokeColor);
        ellipseMode(CENTER);
        ellipse(xc, yc, wc, hc);
        noStroke();
        textAlign(CENTER);
        text(sb.toString(), xc, yc + hc/2 + 16);
        popStyle();
    }

    /*private void initBrainFlowMetric() {
        BrainFlowModelParams modelParams = new BrainFlowModelParams(
                focusMetric.getMetric().get_code()
                //focusClassifier.getClassifier().get_code()
                );
        mlModel = new MLModel (modelParams);
        try {
            mlModel.prepare();
        } catch (BrainFlowError e) {
            e.printStackTrace();
        }
    }*/

    //Called on haltSystem() when GUI exits or session stops
    /*public void endSession() {
        try {
            mlModel.release();
        } catch (BrainFlowError e) {
            e.printStackTrace();
        }
    }*/

    private void onColorChange() {
        switch(focusColors) {
            case GREEN:
                cBack = #ffffff;   //white
                cDark = #3068a6;   //medium/dark blue
                cMark = #4d91d9;    //lighter blue
                cFocus = #b8dc69;   //theme green
                cWave = #ffdd3a;    //yellow
                cPanel = #f5f5f5;   //little grey
                break;
            case ORANGE:
                cBack = #ffffff;   //white
                cDark = #377bc4;   //medium/dark blue
                cMark = #5e9ee2;    //lighter blue
                cFocus = #fcce51;   //orange
                cWave = #ffdd3a;    //yellow
                cPanel = #f5f5f5;   //little grey
                break;
            case CYAN:
                cBack = #ffffff;   //white
                cDark = #377bc4;   //medium/dark blue
                cMark = #5e9ee2;    //lighter blue
                cFocus = #91f4fc;   //cyan
                cWave = #ffdd3a;    //yellow
                cPanel = #f5f5f5;   //little grey
                break;
        }
    }

    /*void channelSelectFlexWidgetUI() {
        //focusBar.setPlotPosAndOuterDim(myNewChanSelect.isVisible());
        focusBar.setPlotPosAndOuterDim(false);
        int factor = myNewChanSelect.isVisible() ? 1 : -1;
        yc += navHeight * factor;
        resizeTable();
        //updateAuditoryNeurofeedbackPosition();
    }*/

    // upon selecting differnet time windows
    public void setFocusHorizScale(int n) {
        xLimit = xLimit.values()[n];
        focusBar.adjustTimeAxis(xLimit.getValue());
    }

    // upon selecting differnet metrics
    public void setMetric(int n) {
        focusMetric = focusMetric.values()[n];
        leftHand = true;
        //endSession();
        //initBrainFlowMetric();
    }

    /*public void setClassifier(int n) {
        focusClassifier = focusClassifier.values()[n];
        endSession();
        initBrainFlowMetric();
    }*/

    // upon selecting different thresholds
    public void setThreshold(int n) {
        focusThreshold = focusThreshold.values()[n];
    }

    // used to help change the color of the focus circle
    public int getMetricExceedsThreshold() {
        return predictionExceedsThreshold ? 1 : 0;
    }

    //public void killAuditoryFeedback() {
    //    auditoryNeurofeedback.killAudio();
    //}

    // Called in DataProcessing.pde to update data even if widget is closed
    public void updateFocusWidgetData() {
        metricPrediction = updateFocusState();
        predictionExceedsThreshold = metricPrediction > focusThreshold.getValue();
    }
    /* End of copy */

};

//These functions need to be global! These functions are activated when an item from the corresponding dropdown is selected
/*void Test1(int n){
    println("Item " + (n+1) + " selected from Dropdown 1");
    if(n==0){
        //do this
    } else if(n==1){
        //do this instead
    }
}

void Test2(int n){
    println("Item " + (n+1) + " selected from Dropdown 2");
}

void Test3(int n){
    println("Item " + (n+1) + " selected from Dropdown 3");
}*/

/* Beginning of copy */
//The following global functions are used by the Focus widget dropdowns. This method is the least amount of code.
/*public void SpectrogramMaxFreq(int n) {
    settings.spectMaxFrqSave = n;
    //reset the vertical axis labels
    w_spectrogram.vertAxisLabel = w_spectrogram.vertAxisLabels[n];
    //Resize the height of the data image
    w_spectrogram.dataImageH = w_spectrogram.vertAxisLabel[0] * 2;
    //overwrite the existing image because the sample rate is about to change
    w_spectrogram.dataImg = createImage(w_spectrogram.dataImageW, w_spectrogram.dataImageH, RGB);
}*/

// selecting differnet time windows
public void myFocusWindowDropdown(int n) {
    w_myNewWidget.setFocusHorizScale(n);
}

// selecting differnet metrics
public void myFocusMetricDropdown(int n) {
    w_myNewWidget.setMetric(n);
    if (n == 0) {
        hands = true;
        stimulations = false;
    } else if (n == 1) {
        hands = false;
        stimulations = true;
    }
}

/*public void myFocusClassifierDropdown(int n) {
    w_myNewWidget.setClassifier(n);
}*/

// selecting differnet thresholds
public void myFocusThresholdDropdown(int n) {
    w_myNewWidget.setThreshold(n);
}

// This class contains the time series plot for the our metric over time
class myFocusBar {
    int x, y, w, h;
    int focusBarPadding = 30;
    int xOffset;
    final int nPoints = 30 * 1000;

    GPlot plot; //the actual grafica-based GPlot that will be rendering the Time Series trace
    LinkedList<Float> fifoList; // data values
    LinkedList<Float> fifoTimeList; // time values

    int numSeconds;
    color channelColor; //color of plot trace

    // constructor
    // initializes the plot position, dimensions and appearance
    myFocusBar(PApplet _parent, int xLimit, float yLimit, int _x, int _y, int _w, int _h) { //channel number, x/y location, height, width
        x = _x;
        y = _y;
        w = _w;
        h = _h;
        if (eegDataSource == DATASOURCE_CYTON) {
            xOffset = 22;
        } else {
            xOffset = 0;
        }
        numSeconds = xLimit;

        plot = new GPlot(_parent);
        plot.setPos(x + 36 + 4 + xOffset, y); //match Accelerometer plot position with Time Series
        plot.setDim(w - 36 - 4 - xOffset, h);
        plot.setMar(0f, 0f, 0f, 0f);
        plot.setLineColor((int)channelColors[(NUM_ACCEL_DIMS)%8]);
        plot.setXLim(-numSeconds,0); //set the horizontal scale
        plot.setYLim(0, yLimit); //change this to adjust vertical scale
        //plot.setPointSize(2);
        plot.setPointColor(0);
        plot.getXAxis().setAxisLabelText("Time (s)");
        plot.getYAxis().setAxisLabelText("Confidence Score");
        plot.setAllFontProperties("Arial", 0, 14);
        plot.getXAxis().getAxisLabel().setOffset(float(22));
        plot.getYAxis().getAxisLabel().setOffset(float(focusBarPadding));
        plot.getXAxis().setFontColor(OPENBCI_DARKBLUE);
        plot.getXAxis().setLineColor(OPENBCI_DARKBLUE);
        plot.getXAxis().getAxisLabel().setFontColor(OPENBCI_DARKBLUE);
        plot.getYAxis().setFontColor(OPENBCI_DARKBLUE);
        plot.getYAxis().setLineColor(OPENBCI_DARKBLUE);
        plot.getYAxis().getAxisLabel().setFontColor(OPENBCI_DARKBLUE);

        adjustTimeAxis(numSeconds);

        initArrays();

        //set the plot points for X, Y, and Z axes
        plot.addLayer("layer 1", new GPointsArray(30));
        plot.getLayer("layer 1").setLineColor(ACCEL_X_COLOR);
    }

    // initializations for fifoList and fifoTimeList
    private void initArrays() {
        fifoList = new LinkedList<Float>();
        fifoTimeList = new LinkedList<Float>();
        for (int i = 0; i < nPoints; i++) {
            fifoList.add(0f);
            fifoTimeList.add(0f);
        }
    }

    // when new value comes, it updates graph
    public void update(double val) {
        updateGPlotPoints(val);
    }

    // rendering the plot
    public void draw() {
        plot.beginDraw();
        plot.drawBox(); //we won't draw this eventually ...
        plot.drawGridLines(GPlot.BOTH);
        plot.drawLines(); //Draw a Line graph!
        //plot.drawPoints(); //Used to draw Points instead of Lines
        plot.drawYAxis();
        plot.drawXAxis();
        plot.getXAxis().draw();
        plot.endDraw();
    }

    // updates the x-axis and re-initializes the fifoList and fifoTimeList
    public void adjustTimeAxis(int _newTimeSize) {
        numSeconds = _newTimeSize;
        plot.setXLim(-_newTimeSize,0);
        initArrays();
        //Set the number of axis divisions...
        if (_newTimeSize > 1) {
            plot.getXAxis().setNTicks(_newTimeSize);
        }else{
            plot.getXAxis().setNTicks(10);
        }
    }

    // Used to update the Points within the graph
    private void updateGPlotPoints(double val) {
        float timerVal = (float)millis() / 1000.0;
        fifoTimeList.removeFirst();
        fifoTimeList.addLast(timerVal);
        fifoList.removeFirst();
        fifoList.addLast((float)val);

        int stopId = 0;
        for (stopId = nPoints - 1; stopId > 0; stopId--) {
            if (timerVal - fifoTimeList.get(stopId) > numSeconds) {
                break;
            }
        }
        int size = nPoints - 1 - stopId;
        GPointsArray focusPoints = new GPointsArray(size);
        for (int i = 0; i < size; i++) {
            focusPoints.set(i, fifoTimeList.get(i + stopId) - timerVal, fifoList.get(i + stopId), "");
        }
        plot.setPoints(focusPoints, "layer 1");
    }

    public void screenResized(int _x, int _y, int _w, int _h) {
        x = _x;
        y = _y;
        w = _w;
        h = _h;
        // reposition & resize the plot
        plot.setPos(x + 36 + 4 + xOffset, y);
        plot.setDim(w - 36 - 4 - xOffset, h);

    }

    // resizing if we have channel selections
    public void setPlotPosAndOuterDim(boolean chanSelectIsVisible) {
        int _y = chanSelectIsVisible ? y + 22 : y;
        int _h = chanSelectIsVisible ? h - 22 : h;
        //reposition & resize the plot
        plot.setPos(x + 36 + 4 + xOffset, _y);
        plot.setDim(w - 36 - 4 - xOffset, _h);
    }

}; //end of class
/* End of copy */

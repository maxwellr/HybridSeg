//
//  MFPController.m
//  Caps64
//
//  Created by Capstone Group 64 on 2015-01-16.
//
//
#define MAX_PIXEL_VALUE 255.0
#define HOUNS_OFFSET 1024.0
#define MAX_BIT 255.0
#define HOUNS_MAX 5120.0
#define IMG_SIZE 512
#define LWR_LUNG_AREA 200.0
#define UPR_LUNG_AREA 50000.0
#define LUNG_THRESH 33
#define BONE_THRESH 254.0 //lower value picks up more grey stuff. can't be >255
#define SOFT_THRESH 30.0
#define SOFT_BOUND 50000.0
#define SOFT_WNDW 350
#define SOFT_LVL 40
#define LUNG_WNDW 1500
#define LUNG_LVL 300
#define BONE_MAX 92
#import "MFPController.h"

@implementation MFPController
@synthesize  Vctrl;
@synthesize LW;
@synthesize LL;
@synthesize BW;
@synthesize BL;
@synthesize RW;
@synthesize RL;
@synthesize lungPop;
@synthesize bonePop;
@synthesize restPop;


- (void)windowDidLoad {
    [super windowDidLoad];
    
    // Implement this method to handle any initialization after your window controller's window has been loaded from its nib file.
}

///* Copy the OsiriX active window pointer
-(void)initViewerW:(NSArray*) mViewer{
    
    Vctrl = [[NSArray alloc] initWithArray:mViewer];
    NSLog(@"%d", [Vctrl count]);
    
}

//***************** Update Window Levels *******************
//After user chooses drop down or manual level, LW, LL, etc updates

-(IBAction)PopChanged:(id)pId{
    
    int slung= [lungPop indexOfSelectedItem];
    int sbone= [bonePop indexOfSelectedItem];
    int srest= [restPop indexOfSelectedItem];
    
    NSPopUpButton* whichPop= (NSPopUpButton*) pId;
    
    if(lungPop==whichPop){ // this should check whether lung changed
        
        if (slung == 0){
            //Lung1
            [LW setStringValue:@"1400"];
            [LL setStringValue:@"-700"];
        }
        else if (slung == 1){
            //Lung2
            [LW setStringValue:@"1400"];
            [LL setStringValue:@"-600"];
        }
        else{
            //Lung3
            [LW setStringValue:@"1400"];
            [LL setStringValue:@"-500"];
        }
    }
    
    else if(bonePop==whichPop){
        
        [BW setStringValue:@"1500"];
        [BL setStringValue:@"300"];
    }
    
    else{
        
        if (srest == 0){
            //Mediastinum
            [RW setStringValue:@"350"];
            [RL setStringValue:@"40"];
        }
        else{
            //Liver
            [RW setStringValue:@"250"];
            [RL setStringValue:@"100"];
        }
    }
    
}


- (IBAction)doSomething:(id)pId
{
    NSAlert *alert = [[NSAlert alloc] init];
    [alert setMessageText:@"Starting Segmentation."];
    [alert setInformativeText:@"Press OK to Start"];
    [alert addButtonWithTitle:@"Ok"];
    [alert runModal];
    [self initMasks];
    
} // end doSomething

- (IBAction)CallUpdate:(id)pId{
    [self UpdateView];
}

//****************** CONVERT Hounsfield TO GRAYSCALE **************
//INPUTS: float matrix of DICOM image
//OUTPUTS: unsigned char matrix in 8-bit grayscale

-(unsigned char) DcmPixtoGRY:(float)DcmPix
{
    return (DcmPix + HOUNS_OFFSET) * MAX_BIT/HOUNS_MAX;
}

//****************** CONVERT Grayscale TO Hounsfield **************
//INPUTS: unsigned char matrix in 8-bit grayscale
//OUTPUTS: float matrix of DICOM image

-(float) GRYtoDcmPix:(unsigned char)GRY
{
    return (float)GRY * HOUNS_MAX/MAX_BIT - HOUNS_OFFSET;
}


//****************** GENERATE HYBRID IMAGE ******************
//INPUTS: CT Slice as openCV MAT type, slice number in study
//OUTPUTS: Hybrid CT slice

-(Mat) ApplyHybrid:(Mat)Slice :(int)SliceN{
    
    Mat hybrid = cv::Mat::zeros(Slice.size(),Slice.type());
    Mat lungs = hybrid.clone();
    Mat bones = hybrid.clone();
    Mat soft = hybrid.clone();
    Mat temp = Slice.clone();
    
    //Copy pixels from slice into lungs according to Lung Mask
    temp.copyTo(lungs,lungMask[SliceN]);
    //Apply lung window
    lungs = [self applyWin:(lungs) :([LW floatValue]) :([LL floatValue])];
    //Copy pixels from slice into bones according to Bone Mask
    temp.copyTo(bones,boneMask[SliceN]);
    //Apply bone window
    bones = [self applyWin:(bones) :([BW floatValue]) :([BL floatValue])];
    if(SliceN == 60 ){
        imshow("bone mask", boneMask[SliceN]);
        imshow("bone",bones);
    }
    
    temp.copyTo(soft,softMask[SliceN]);
    soft = [self applyWin:(soft) :([RW floatValue]) :([RL floatValue])];
    
    //Combine Tissues together
    addWeighted(lungs, 1, bones, 1, 0.0, hybrid);
    addWeighted(hybrid, 1, soft, 1, 0.0, hybrid);
    
    return hybrid;
}


//**************** OUTPUT HYBRID IMAGES ***************

- (void) UpdateView{
    float            *fImage;   // Grey Image
    Mat res;
    
    NSArray     *PixList = [[Vctrl firstObject] pixList];
    
    int i;
    for (i = 0; i < [PixList count]; i++) //i<
    {
        
        DCMPix      *curPix = [PixList objectAtIndex: i];
        
        int curPos = [curPix pheight] * [curPix pwidth];  // Number of Pixels
        fImage = [curPix fImage];
        
        int x,y;
        Mat SliceInMat = orgSeries[i].clone();
        res=[self ApplyHybrid:(SliceInMat):(i)];
        
        for (x = 0; x < [curPix pwidth]; x++)
            for (y = 0; y < [curPix pheight]; y++)
            {
                
                curPos = y * [curPix pwidth] + x;
                fImage[curPos] = [self GRYtoDcmPix:(res.data[curPos])];
                
            }
    }
}

//******************** CREATE BINARY MASKS **************
//User presses InitMasks to start segmentation
//Bone and Lung binary masks generated and stored in global variables

-(void) initMasks
{
    
    float            *fImage;   // Grey Image
    unsigned char           tdimg[IMG_SIZE * IMG_SIZE];
    
    
    NSArray     *PixList = [[Vctrl firstObject] pixList];
    
    int i;
    for (i = 0; i < [PixList count]; i++) //i<
    {
        
        DCMPix      *curPix = [PixList objectAtIndex: i];
        
        int curPos = [curPix pheight] * [curPix pwidth];  // Number of Pixels
        fImage = [curPix fImage];
        
        int x,y;
        
        for (x = 0; x < [curPix pwidth]; x++)
            for (y = 0; y < [curPix pheight]; y++)
            {
                
                curPos = y * [curPix pwidth] + x;
                float GreyValue;
                GreyValue = fImage[curPos];
                tdimg[curPos]=[self DcmPixtoGRY:(GreyValue)]; //convert dicom pixel to grayscale pixel
                
            }
        
        Mat TestImg= Mat(cv::Size(IMG_SIZE,IMG_SIZE),CV_8UC1, &tdimg);
       
        Mat lungMaskIm = [self lung_seg:(TestImg)];
        Mat BoneMaskIm = [self bone_seg:(TestImg)];
        Mat SoftMaskIm = [self soft_seg:TestImg :lungMaskIm :BoneMaskIm];
        
        lungMask.push_back(lungMaskIm.clone());
        boneMask.push_back(BoneMaskIm.clone());
        softMask.push_back(SoftMaskIm.clone());
        orgSeries.push_back(TestImg.clone());
    }
}

//***************** WINDOW IMAGE *****************
//INPUTS: MAT image, float window width, float window level
//OUTPUTS: MAT image at that window

- (Mat) applyWin:(Mat)image :(float) wndw :(float) level{
    
    float gray_wndw = (wndw) * MAX_BIT/HOUNS_MAX;
    float gray_level = (level + HOUNS_OFFSET) * MAX_BIT/HOUNS_MAX;
    
    Mat wndwed_img = Mat::zeros(image.size(),image.type());
    float a = gray_level - gray_wndw/2;
    if (a<0){ a=0;}
    
    float b = gray_level + gray_wndw/2;
    if (b>MAX_PIXEL_VALUE){ b=MAX_PIXEL_VALUE;}
    
    float step = MAX_PIXEL_VALUE/(b-a);
    int i,k;
    
    for(i = 0; i<IMG_SIZE ; i++){
        for(k = 0; k<IMG_SIZE; k++){
            
            if(image.at<uchar>(i,k) < a)
                wndwed_img.at<uchar>(i,k) = 0;
            
            else if(image.at<uchar>(i,k) > b)
                wndwed_img.at<uchar>(i,k) = MAX_PIXEL_VALUE;
            
            else
                wndwed_img.at<uchar>(i,k) = (image.at<uchar>(i,k) - a) * step;
        }
    }
    
    return wndwed_img;
    
}

//***************** LUNG SEGMENTATION FUNCTION *****************
//INPUTS: MAT image at default window level
//OUTPUTS: MAT binary mask, need to apply BW to appropriate windowed dicom image.

- (Mat) lung_seg:(Mat)org_img
{
    // Copy image
    Mat src_image = org_img.clone();
    
    if (src_image.empty())
    {
        return org_img;
    }
    
    Mat bgr_image = src_image.clone();
    bgr_image = [self applyWin:bgr_image :LUNG_WNDW :LUNG_LVL];
    
    //erode and dilate image to remove nodules in lungs
    int erosion_type = cv::MORPH_RECT;
    int erosion_size = 2.8;
    Mat element = cv::getStructuringElement(erosion_type,cv::Size(2 * erosion_size + 1, 2 * erosion_size + 1),cv::Point(erosion_size, erosion_size));
    
    erode(bgr_image, bgr_image, element);
    dilate(bgr_image, bgr_image, element);
    
    //produce binary image by thresholding
    Mat init_lungbw;
    cv::threshold(bgr_image, init_lungbw, LUNG_THRESH, 255, THRESH_BINARY);
    //inRange(bgr_image, Scalar(LWR_LUNG_THRESH), Scalar(UPR_LUNG_THRESH), init_lungbw);
    
    // Find the border of the lungs by using findContours
    cv::vector<vector<cv::Point> > lung_borders;
    cv::vector<Vec4i> hierachy;
    
    findContours(init_lungbw, lung_borders, hierachy, RETR_LIST, CHAIN_APPROX_SIMPLE);
    //Chain_approx_simple reduces number of contour points
    
    // Filter the found borders to just the lungs using area, fill lung regions
    Mat lungs = src_image.clone();
    cv::vector<cv::Point> contour;
    double lung_area;
    Scalar color(0,0,255);
    
    for (size_t i = 0; i < lung_borders.size(); i++)
    {
        contour = lung_borders[i];
        lung_area = contourArea(Mat(contour));
        
        if (lung_area > LWR_LUNG_AREA && lung_area < UPR_LUNG_AREA)//area criteria
        {
            drawContours(lungs, lung_borders, i, color,CV_FILLED, 8, hierachy,0,cv::Point());//filling the lung regions
        }
    }
    
    // Extract filled regions using inRange
    Mat lung_BW = cv::Mat::zeros(src_image.size(), src_image.type());
    inRange(lungs, color, color, lung_BW);
    
    //erosion to remove small parts, white borders still remain
    erosion_size = 1.1;
    element = getStructuringElement(erosion_type,cv::Size(2 * erosion_size + 1, 2 * erosion_size + 1),cv::Point(erosion_size, erosion_size));
    erode(lung_BW, lung_BW, element);
    
    //erosion_size = 1.1;
    //element = getStructuringElement(erosion_type,cv::Size(2 * erosion_size + 1, 2 * erosion_size + 1),cv::Point(erosion_size, erosion_size));
    dilate(lung_BW, lung_BW, element);
    
    return lung_BW;

}


//************* BONE SEGMENTATION FUNCTION *****************
//INPUTS: orginal CT slice as MAT image
//OUTPUTS: binary bone mask as openCV MAT type

-(Mat) bone_seg:(Mat) org_img{
    
    Mat binary = org_img.clone();
    
    if (binary.empty())
    {
        return org_img;
    }
    //binary = [self applyWin:binary :2682 :1171]; //random WL tried in osirix for a better segmentation of the bones to exclude the soft tissue. this has a bone_thresh of 40
    binary = [self applyWin:binary :SOFT_WNDW :SOFT_LVL];
    //binary = [self applyWin:binary :1847 :1155];
    cv::threshold(binary, binary, BONE_THRESH, 255, THRESH_BINARY);
    
    Mat erode;
    cv::erode(binary,erode,cv::Mat(),cv::Point(-1,-1),1.2);
    
    Mat dilate;
    cv::dilate(binary,dilate,cv::Mat(),cv::Point(-1,-1),3);
    
    cv::threshold(dilate,dilate,1, 128,cv::THRESH_BINARY_INV);
    
    // add images
      Mat sum(binary.size(),CV_8U,cv::Scalar(0));
    sum= erode+dilate;
   
    sum.convertTo(sum,CV_32S);
    cvtColor(org_img, org_img, CV_GRAY2BGR);
    watershed(org_img, sum);
    sum.convertTo(sum, CV_8U);
    
    Mat bone_BW = cv::Mat::zeros(org_img.size(), org_img.type());
    inRange(sum, cv::Scalar(255, 255, 255), cv::Scalar(255, 255, 255), bone_BW); //fill the extracted mask with white color

    //REMOVING ARTIFACTS
    cv::vector<vector<cv::Point> > borders;
    cv::vector<Vec4i> hierachy;
    
    findContours(bone_BW, borders, hierachy, RETR_LIST, CHAIN_APPROX_SIMPLE);
    //Chain_approx_simple reduces number of contour points
    
    Mat bones = org_img.clone();
    double minVal,maxVal;
    Scalar color(0,0,255);
    
    for (size_t i = 0; i < borders.size(); i++)
    {
        Mat temp = cv::Mat::zeros(org_img.size(),org_img.type());
        drawContours(temp, borders, i, color,CV_FILLED, 8, hierachy,0,cv::Point());
        org_img.copyTo(temp,temp);
        cv::minMaxLoc(temp, &minVal,&maxVal,NULL,NULL,noArray());
        NSLog(@"%f, %f", minVal,maxVal);
        if(maxVal > BONE_MAX)
        {
            drawContours(bones, borders, i, color,CV_FILLED, 8, hierachy,0,cv::Point());
        }
    }
    
    inRange(bones, color, color, bone_BW);
    
    return bone_BW;
}

- (Mat) soft_seg:(Mat) slice :(Mat) lungmask :(Mat) bonemask{
    
    if (slice.empty())
    {
        return slice;
    }
    
    Mat bgr_image = slice.clone();
    
    //erode and dilate image to remove nodules in lungs
    int erosion_type = cv::MORPH_RECT;
    int erosion_size = 3;
    Mat element = cv::getStructuringElement(erosion_type,cv::Size(2 * erosion_size + 1, 2 * erosion_size + 1),cv::Point(erosion_size, erosion_size));
    
    erode(bgr_image, bgr_image, element);
    dilate(bgr_image, bgr_image, element);
    
    //produce binary image by thresholding
    Mat init_softbw;
    cv::threshold(bgr_image, init_softbw, SOFT_THRESH, 255, THRESH_BINARY);
    
    cv::vector<vector<cv::Point> > borders;
    cv::vector<Vec4i> hierachy;
    
    findContours(init_softbw, borders, hierachy, RETR_LIST, CHAIN_APPROX_SIMPLE);
    //Chain_approx_simple reduces number of contour points
    
    Mat soft = slice.clone();
    cv::vector<cv::Point> contour;
    double contourarea;
    Scalar color(0,0,255);
    
    for (size_t i = 0; i < borders.size(); i++)
    {
        contour = borders[i];
        contourarea = contourArea(Mat(contour));
        
        if (contourarea > SOFT_BOUND)//area criteria
        {
            drawContours(soft, borders, i, color,CV_FILLED, 8, hierachy,0,cv::Point());//filling the lung regions
        }
    }
    
    Mat soft_BW = cv::Mat::zeros(slice.size(), slice.type());
    inRange(soft, color, color, soft_BW);
    
    addWeighted(bonemask, -1, soft_BW, 1, 0.0, soft_BW);
    addWeighted(lungmask, -1, soft_BW, 1, 0.0, soft_BW);
    
    
    erosion_size = 1.5;
    element = cv::getStructuringElement(erosion_type,cv::Size(2 * erosion_size + 1, 2 * erosion_size + 1),cv::Point(erosion_size, erosion_size));
    erode(soft_BW, soft_BW, element);
    dilate(soft_BW, soft_BW, element);
    
    return soft_BW;
}

@end

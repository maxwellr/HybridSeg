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
#define BONE_THRESH 253.0 //lower value picks up more grey stuff. can't be >255
#define SOFT_THRESH 30.0
#define SOFT_BOUND 50000.0
#define SOFT_WNDW 350
#define SOFT_LVL 40
#define LUNG_WNDW 1500
#define LUNG_LVL 300
#define BONE_MAX 92
#define PIXEL_CAL 20
#define HRange(A) ((A)<-1024)?-1024:((A>3072)?3072:A)
#define WWRange(A) ((A)<0)?0:((A>4096)?4096:A)
#define insideBoxX(A) (A>128&&A<468)?1:0
#define insideBoxY(A) (A>21&&A<267)?1:0

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

@synthesize CBL;
@synthesize CBB;
@synthesize CBS;


- (void)mouseDown:(NSEvent *)theEvent {

    

    mouseLoc = [self.window.contentView  convertPoint:[theEvent locationInWindow] fromView:nil];
  //  NSLog(@"%f %f",mouseLoc.x,mouseLoc.y);
    
    return;
}

-(void)mouseDragged:(NSEvent *)theEvent {
 
    
    NSPoint  mouseLoc1 = [self.window.contentView  convertPoint:[theEvent locationInWindow] fromView:nil];
    NSLog(@"%f %f",mouseLoc1.x-mouseLoc.x,mouseLoc1.y-mouseLoc.y);
    
    
    if(!insideBoxX(mouseLoc1.x) || !insideBoxY(mouseLoc1.y)) return;
    
    
    int dX=cvRound(0.5*(mouseLoc1.x-mouseLoc.x));
    int dY=cvRound(0.5*(mouseLoc1.y-mouseLoc.y));
    
    
    if([CBL state]==NSOnState){
        [LW setFloatValue:WWRange([LW floatValue]+dX)];
        [LL setFloatValue:HRange([LL floatValue]+dY)];
    }
    
    
    if([CBB state]==NSOnState){
        [BW setFloatValue:WWRange([BW floatValue]+dX)];
        [BL setFloatValue:HRange([BL floatValue]+dY)];
    }
    
    
    if([CBS state]==NSOnState){
        [RW setFloatValue:WWRange([RW floatValue]+dX)];
        [RL setFloatValue:HRange([RL floatValue]+dY)];
    }
    
    

    [self updateSingle];
    mouseLoc= [self.window.contentView  convertPoint:[theEvent locationInWindow] fromView:nil];
    return;

    
}

- (void)mouseUp:(NSEvent *)theEvent {
    
    mouseLoc= [self.window.contentView  convertPoint:[theEvent locationInWindow] fromView:nil];

  }

- (void)windowDidLoad {
    [super windowDidLoad];
    
    // Implement this method to handle any initialization after your window controller's window has been loaded from its nib file.
}

///* Copy the OsiriX active window pointer
-(void)initViewerW:(NSArray*) mViewer{
    
    Vctrl = [[NSArray alloc] initWithArray:mViewer];
    NSLog(@"%d", [Vctrl count]);
    
    if([Vctrl count]==2) useSharp=TRUE;
    else useSharp=FALSE;
    
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
    NSDate *start = [NSDate date];
    [self initMasks];
    NSTimeInterval timeInterval = [start timeIntervalSinceNow];
    NSLog(@"Mask generation time is %f seconds", fabs(timeInterval));
    
} // end doSomething

- (IBAction)CallUpdate:(id)pId{
    
    NSDate *start = [NSDate date];
    [self UpdateView];
    NSTimeInterval timeInterval = [start timeIntervalSinceNow];
    NSLog(@"View-Update time is %f seconds", fabs(timeInterval));

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

-(Mat) ApplyHybrid:(int)SliceN{
    
    Mat temp = orgSeries[SliceN].clone();
    Mat tempSharp=temp.clone();
    Mat hybrid = cv::Mat::zeros(temp.size(),temp.type());
    Mat lungs = hybrid.clone();
    Mat bones = hybrid.clone();
    Mat soft = hybrid.clone();
    
    if(useSharp){
        
        tempSharp= orgSeriesSharp[SliceN].clone();
        
    }
    
    
    //Copy pixels from slice into lungs according to Lung Mask
    tempSharp.copyTo(lungs,lungMask[SliceN]);
    //Apply lung window
    lungs = [self applyWin:(lungs) :([LW floatValue]) :([LL floatValue])];
    //Copy pixels from slice into bones according to Bone Mask
    tempSharp.copyTo(bones,boneMask[SliceN]);
    //Apply bone window
    bones = [self applyWin:(bones) :([BW floatValue]) :([BL floatValue])];
    temp.copyTo(soft,softMask[SliceN]);
    soft = [self applyWin:(soft) :([RW floatValue]) :([RL floatValue])];
    
    //Combine Tissues together
    addWeighted(lungs, 1, bones, 1, 0.0, hybrid);
    addWeighted(hybrid, 1, soft, 1, 0.0, hybrid);
    
    return hybrid;
}


//**************** OUTPUT HYBRID IMAGES ***************

-(void)updateSingle{
    int i = [[[Vctrl firstObject] imageView] curImage];

    float            *fImage;   // Grey Image
    Mat res;
    
    NSArray     *PixList = [[Vctrl firstObject] pixList];
    
   
        
        DCMPix      *curPix = [PixList objectAtIndex: i];
        
        int curPos = [curPix pheight] * [curPix pwidth];  // Number of Pixels
        fImage = [curPix fImage];
        
        int x,y;
        Mat SliceInMat = orgSeries[i].clone();
        res=[self ApplyHybrid:(i)];
        
        for (x = 0; x < [curPix pwidth]; x++)
            for (y = 0; y < [curPix pheight]; y++)
            {
                
                curPos = y * [curPix pwidth] + x;
                fImage[curPos] = [self GRYtoDcmPix:(res.data[curPos])];
                
            }

    [[Vctrl firstObject] needsDisplayUpdate];
    
}

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
       // Mat SliceInMat = orgSeries[i].clone();
        res=[self ApplyHybrid:(i)];
        
        for (x = 0; x < [curPix pwidth]; x++)
            for (y = 0; y < [curPix pheight]; y++)
            {
                
                curPos = y * [curPix pwidth] + x;
                fImage[curPos] = [self GRYtoDcmPix:(res.data[curPos])];
                
            }
    }
     [[Vctrl firstObject] needsDisplayUpdate];
}

//******************** CREATE BINARY MASKS **************
//User presses InitMasks to start segmentation
//Bone and Lung binary masks generated and stored in global variables

-(void) initMasks
{
    
    float            *fImage;   // Grey Image
    unsigned char           tdimg[IMG_SIZE * IMG_SIZE];
    
    
    NSArray     *PixList = [[Vctrl firstObject] pixList];
    
    
//Find avg pixel value accross all pixels. Might be used for normalizing
    double avgg=0;
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
                //tdimg[curPos]=[self DcmPixtoGRY:(GreyValue)]; //convert dicom pixel to grayscale pixel
                avgg+=[self DcmPixtoGRY:(GreyValue)]*1.0/(IMG_SIZE*IMG_SIZE*[PixList count]);
                
            }
    
        
        
    }
    
    NSLog(@"average pixel value: %f ", avgg);
//End of find avg
    
    
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
               // tdimg[curPos]=MAX([self DcmPixtoGRY:(GreyValue)]+(PIXEL_CAL-avgg),0); //convert dicom pixel to grayscale pixel
                tdimg[curPos]=[self DcmPixtoGRY:(GreyValue)];
                
            }
        
        Mat TestImg= Mat(cv::Size(IMG_SIZE,IMG_SIZE),CV_8UC1, &tdimg);
        
        Mat lungMaskIm = [self lung_seg:(TestImg) :0];
        //Mat lungborderMask = [self lung_seg:(TestImg) :1];
        Mat BoneMaskIm = [self bone_seg:(TestImg)];
        Mat SoftMaskIm = [self soft_seg:TestImg :lungMaskIm :BoneMaskIm];
        
        lungMask.push_back(lungMaskIm.clone());
        boneMask.push_back(BoneMaskIm.clone());
        softMask.push_back(SoftMaskIm.clone());
        orgSeries.push_back(TestImg.clone());
        
        Mat border;
        //addWeighted(lungMaskIm, 1, lungborderMask, -1, 0.0, border);
        
//        if(i==60){
//            TestImg = [self applyWin:TestImg :LUNG_WNDW :LUNG_LVL];
//            Mat image = TestImg.clone();
//            int histSize = 256;
//            float range[] = {0,256};
//            const float* histRange = {range};
//            bool uniform = true; bool accumlate = false;
//            Mat hist;
//            
//            //calculate histogram
//            calcHist(&image, 1, 0, Mat(), hist, 1, &histSize, &histRange,uniform,accumlate);
//            
//            int hist_w = 512; int hist_h = 300;
//            int bin_w = cvRound((double)hist_w/histSize);
//            Mat histImage(hist_h,hist_w,CV_8UC3,Scalar(0,0,0));
//            
//            //normalize histogram according to plot size
//            normalize(hist,hist,0,histImage.rows,NORM_MINMAX,-1,Mat());
//            
//            for(int j=1;j<histSize;j++){
//                line(histImage,cv::Point(bin_w*(j-1),hist_h - cvRound(hist.at<float>(j-1))),
//                     cv::Point(bin_w*(j),hist_h-cvRound(hist.at<float>(j))),Scalar(255,0,0),2,8,0);
//            }
//            
//            imshow("org",TestImg);
//            imshow("hist",histImage);
//        }
        
//        if(i==40){
//            imshow("lung1_40",border);
//        }
//        if(i==20){
//            imshow("lung1_20",border);
//        }
//        if(i==60){
//            imshow("lung1_60",border);
//        }
//        if(i==80){
//            imshow("lung1_80",border);
//        }
        
        
        //check to see if there is any overlap between lungs and bone
//        Mat overlap;
//        bitwise_and(lungMaskIm, BoneMaskIm, overlap);
//        int count = countNonZero(overlap);
//        if(count>0)
//            NSLog(@"Slice %d has overlap by %d pixels",i,count);

        
//        if(i==100 || i==80 || i==60 || i==40 || i==20){
//            
//            double thresh = [self findthresh:TestImg];
//            NSLog(@"Lung threshold is: %f", thresh);

//            Mat orghist = [self drawhist:TestImg];
//            imshow("orghist",orghist);
            
//            imshow("EqualHist",lungMaskIm);
//            Mat eqhist = [self drawhist:lungMaskIm];
//            imshow("eqhist",eqhist);

//            Mat claheimg = TestImg.clone();
//            Ptr<CLAHE> clahe = createCLAHE(2,cv::Size(10,10));
//            clahe->apply(claheimg,claheimg);
//            
//            imshow("clahe",claheimg);
//            Mat clahehist = [self drawhist:claheimg];
//            imshow("clahehist",clahehist);
//            
//            claheimg = TestImg.clone();
//            clahe = createCLAHE(2,cv::Size(20,20));
//            clahe->apply(claheimg,claheimg);
//            
//            imshow("clahe_clip25",claheimg);
//            clahehist = [self drawhist:claheimg];
//            imshow("clahehist_clip25",clahehist);
//            
//            claheimg = TestImg.clone();
//            clahe = createCLAHE(2,cv::Size(30,30));
//            clahe->apply(claheimg,claheimg);
//            
//            imshow("clahe_size30",claheimg);
//            clahehist = [self drawhist:claheimg];
//            imshow("clahehist_size30",clahehist);
        
//            GaussianBlur(TestImg, TestImg, cv::Size(5,5), 0);
//            threshold(TestImg,TestImg,0,255,CV_THRESH_BINARY | CV_THRESH_OTSU);
//            imshow("Otsu",TestImg);
//            
//            GaussianBlur(lungMaskIm, lungMaskIm, cv::Size(5,5), 0);
//            threshold(lungMaskIm,lungMaskIm,0,255,CV_THRESH_BINARY | CV_THRESH_OTSU);
//            imshow("Otsu EqualHist",lungMaskIm);
            
            
        //}
        
    }
    
    
    //if sharp kernel image is avaliable save it to memory
    if(useSharp){
        
        NSArray     *PixList = [Vctrl[1] pixList]; //sharp kernel is the one to the right

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
                    // tdimg[curPos]=MAX([self DcmPixtoGRY:(GreyValue)]+(PIXEL_CAL-avgg),0); //convert dicom pixel to grayscale pixel
                    tdimg[curPos]=[self DcmPixtoGRY:(GreyValue)];
                    
                }
            
            Mat TestImg= Mat(cv::Size(IMG_SIZE,IMG_SIZE),CV_8UC1, &tdimg);
            

            orgSeriesSharp.push_back(TestImg.clone());
        }
        
        
        
        
    }
    
}

//************** CALCULATE AND CHANGE HISTOGRAM ***********

-(double) findthresh:(Mat)image{
    
    int histSize = 256;
    float range[] = {0,256};
    const float* histRange = {range};
    bool uniform = true; bool accumlate = false;
    Mat hist;
    
    //calculate histogram
    calcHist(&image, 1, 0, Mat(), hist, 1, &histSize, &histRange,uniform,accumlate);
    
    int hist_w = 512; int hist_h = 300;
    int bin_w = cvRound((double)hist_w/histSize);
    Mat histImage(hist_h,hist_w,CV_8UC3,Scalar(0,0,0));
    
    //normalize histogram according to plot size
    normalize(hist,hist,0,histImage.rows,NORM_MINMAX,-1,Mat());
    
    //find maximum of histogram
    double min,max;
    minMaxLoc(hist, &min,&max);
    
    //set threshold according to max
    double thresh = 0.05*max;
    
    //below threshold -> 0
    for(int j=0;j<histSize;j++){
        if(hist.at<float>(j) < thresh)
            hist.at<float>(j) = 0;
    }
    
    normalize(hist,hist,0,histImage.rows,NORM_MINMAX,-1,Mat());
    
    int count = 1;
    int lastbin;
    
    //finds the rightmost non-zero bin
    for(int j=histSize-1; j>=0; j--){
        if(hist.at<float>(j) != 0 && count != 0){
            lastbin = j;
            count--;
        }
    }
    
    //set lung threshold
    double lung_thresh = 0.25*lastbin;
    
    //draw histogram
//    for(int j=1;j<histSize;j++){
//        line(histImage,cv::Point(bin_w*(j-1),hist_h - cvRound(hist.at<float>(j-1))),
//             cv::Point(bin_w*(j),hist_h-cvRound(hist.at<float>(j))),Scalar(255,0,0),2,8,0);
//    }
////
////    //line(histImage,cv::Point(lastbin*bin_w,0),cv::Point(lastbin*bin_w,hist_h),Scalar(0,255,0),2,8,0);
////    //line(histImage,cv::Point(lung_thresh*3*bin_w,0),cv::Point(lung_thresh*3*bin_w,hist_h),Scalar(0,0,255),2,8,0);
////    
//    imshow("hist",histImage);
    
    return lung_thresh;
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

- (Mat) lung_seg:(Mat)org_img :(int) type
{
    // Copy image
    Mat src_image = org_img.clone();
    
    if (src_image.empty())
    {
        return org_img;
    }
    
    Mat bgr_image = src_image.clone();
    
    if(type == 1){
        bgr_image = [self applyWin:bgr_image :1500 :-700];
    
        //erode and dilate image to remove nodules in lungs
        int erosion_type = cv::MORPH_ELLIPSE;
        //ADJUST SIZE MAYBE?
        int erosion_size = 1.2;
        Mat element = cv::getStructuringElement(erosion_type,cv::Size(2 * erosion_size + 1, 2 * erosion_size + 1),cv::Point(erosion_size, erosion_size));
    
        erode(bgr_image, bgr_image, element);
        dilate(bgr_image, bgr_image, element);
   
        //produce binary image by thresholding
        Mat init_lungbw;
        double lung_thresh = [self findthresh:bgr_image]*2;
        cv::threshold(bgr_image, init_lungbw, lung_thresh, 255, THRESH_BINARY);

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
    
        int kerneltype = cv::MORPH_ELLIPSE;
        int kernelsize = 3;
        Mat kernel = cv::getStructuringElement(kerneltype, cv::Size(2*kernelsize+1,2*kernelsize+1),cv::Point(kernelsize,kernelsize));
        morphologyEx(lung_BW, lung_BW, MORPH_OPEN, kernel);
        
        return lung_BW;
    }
    
    if(type == 0){
        
        bgr_image = [self applyWin:bgr_image :LUNG_WNDW :LUNG_LVL];
    
        //erode and dilate image to remove nodules in lungs
        int erosion_type = cv::MORPH_ELLIPSE;
        //ADJUST SIZE MAYBE?
        int erosion_size = 1.2;
        Mat element = cv::getStructuringElement(erosion_type,cv::Size(2 * erosion_size + 1, 2 * erosion_size + 1),cv::Point(erosion_size, erosion_size));
    
        erode(bgr_image, bgr_image, element);
        dilate(bgr_image, bgr_image, element);

        //produce binary image by thresholding
        Mat init_lungbw;
        double lung_thresh = [self findthresh:bgr_image];
        cv::threshold(bgr_image, init_lungbw, lung_thresh, 255, THRESH_BINARY);
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
    
        int kerneltype = cv::MORPH_ELLIPSE;
        int kernelsize = 3;
        Mat kernel = cv::getStructuringElement(kerneltype, cv::Size(2*kernelsize+1,2*kernelsize+1),cv::Point(kernelsize,kernelsize));
        morphologyEx(lung_BW, lung_BW, MORPH_OPEN, kernel);

        return lung_BW;
    }
    else
        return bgr_image;

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
    
    //double bone_thresh = [self findthresh:binary]*4;
    //double bone_thresh = [self findthresh:binary];

    //NSLog(@"thresh %f",bone_thresh);
    cv::threshold(binary, binary, BONE_THRESH, 255, THRESH_BINARY);
    
    Mat erode;
    cv::erode(binary,erode,cv::Mat(),cv::Point(-1,-1));
    
    Mat dilate;
    cv::dilate(binary,dilate,cv::Mat(),cv::Point(-1,-1),2);
    
    cv::threshold(dilate,dilate,1, 128,cv::THRESH_BINARY_INV);
    
    // add images
      Mat sum(binary.size(),CV_8U,cv::Scalar(0));
    sum= erode+dilate;
    //  addWeighted(erode, 1, dilate, 1, 0.0, sum);
   
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
        //NSLog(@"%f, %f", minVal,maxVal);
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
    int erosion_type = cv::MORPH_ELLIPSE;
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
    
    //overlap between bone and lung -> make negatives 0
    for(int i = 0; i<slice.rows; i++){
        for(int j=0; j<slice.cols; j++){
            if(soft_BW.at<uchar>(i,j) < 0)
                soft_BW.at<uchar>(i,j) = 0;
        }
    }
    
    int kerneltype = cv::MORPH_ELLIPSE;
    int kernelsize = 3;
    Mat kernel = cv::getStructuringElement(kerneltype, cv::Size(2*kernelsize+1,2*kernelsize+1),cv::Point(kernelsize,kernelsize));
    morphologyEx(soft_BW, soft_BW, MORPH_OPEN, kernel);
    
    return soft_BW;
}

@end

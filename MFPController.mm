//
//  MFPController.m
//  Caps64
//
//  Created by Capstone Group 64 on 2015-01-16.
//
//

#import "MFPController.h"



@implementation MFPController
@synthesize  Vctrl;
- (void)windowDidLoad {
    [super windowDidLoad];
    
    // Implement this method to handle any initialization after your window controller's window has been loaded from its nib file.
}
///*
-(void)initViewerW:(ViewerController*) mViewer{
    
    Vctrl=mViewer;
}
//*/
- (IBAction)doSomething:(id)pId;
{
    NSAlert *alert = [[NSAlert alloc] init];
    [alert setMessageText:@"Starting Seg."];
    [alert setInformativeText:@"PleaseWait."];
    [alert addButtonWithTitle:@"Ok"];
    [alert runModal];
    [self applyFilterToSeries];
 
} // end doSomething
-(void) applyFilterToSeries
{
    
    
    float            *fImage;   // Grey Image
    unsigned char           tdimg[512][512];
  
    
    NSArray     *PixList = [Vctrl pixList];
    
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
                
                // Reading Pixel
                GreyValue = fImage[curPos];
                
                tdimg[x][y]=(GreyValue+1024)*256/4096.0;
                
                // Basic segmentation
                
              //  if(GreyValue > -600.0)
                //    fImage[curPos] = 0;
                //else
                  //  fImage[curPos] = GreyValue;
                
            }
        
        
        
        Mat testImage(512,512,CV_8UC1, tdimg);
       // namedWindow("TEST",CV_WINDOW_AUTOSIZE);
        //imshow("TEST",testImage);
        Mat res;
        res=[self lung_seg:testImage];
        
        
        
        for (x = 0; x < [curPix pwidth]; x++)
            for (y = 0; y < [curPix pheight]; y++)
            {
                
                curPos = y * [curPix pwidth] + x;
                
                // float a=dst.at<float>(x,y);
                
                
                // Basic segmentation
                
                fImage[curPos] = (res.at<unsigned char>(x,y))*4096.0/256-1024;
                
            }
        
     
    }
}

- (Mat) lung_seg:(Mat)org_img;
{
    // Load image .
    Mat src_image = org_img.clone();
    if (src_image.empty())
    {
        return org_img;
    }
    
    // Converting DICOM image to grayscale with 1-channel in order to use cv functions
    Mat bgr_image = src_image.clone();
    
    //Bonewindow to make lungs darker?*************************
    //use Guassian blur and histograms?
    
    //erode and dilate image to remove nodules in lungs
    int erosion_type = cv::MORPH_RECT;
    int erosion_size = 3;
    Mat element = cv::getStructuringElement(erosion_type,cv::Size(2 * erosion_size + 1, 2 * erosion_size + 1),cv::Point(erosion_size, erosion_size));
    
    cv::erode(bgr_image, bgr_image, element);
    cv::dilate(bgr_image, bgr_image, element);
    
    //Display Eroded/Dilated Image
    //namedWindow("Eroded Lungs",CV_WINDOW_AUTOSIZE);
    //imshow("Eroded Lungs",bgr_image);
    
    //produce binary image by thresholding
    Mat init_lungbw;
    cv::threshold(bgr_image, init_lungbw, 20, 255, cv::THRESH_BINARY);
    
    //Display threshold image
    //namedWindow("Thresholded Lungs",CV_WINDOW_AUTOSIZE);
    //imshow("Thresholded Lungs",init_lungbw);
    
    // Find the border of the lungs by using findContours
    std::vector<std::vector<cv::Point> > lung_borders;
    cv::findContours(init_lungbw, lung_borders, cv::RETR_LIST, cv::CHAIN_APPROX_SIMPLE);
    //Chain_approx_simple reduces number of contour points
    
    // Filter the found borders to just the lungs using area, fill lung regions
    Mat lungs = src_image.clone();
    
    for (size_t i = 0; i < lung_borders.size(); i++)
    {
        std::vector<cv::Point> cnt = lung_borders[i];
        double lung_area = cv::contourArea(cv::Mat(cnt));
        
        if (lung_area > 200 && lung_area < 50000)//area criteria, might need to adjust
        {
            cv::drawContours(lungs, lung_borders, i, cv::Scalar(0, 255, 0),
                             CV_FILLED, 8, std::vector<cv::Vec4i>(), 0, cv::Point());//filling the lung regions in red
        }
    }
    
    //Filled lungs
    //namedWindow("Filled Image",CV_WINDOW_AUTOSIZE);
    //imshow("Filled Image",lungs);
    
    // Apply red region as binary mask to extract windowed lungs
    Mat red_BW = cv::Mat::zeros(src_image.size(), CV_8UC1);
    cv::inRange(lungs, cv::Scalar(0, 255, 0), cv::Scalar(0, 255, 0), red_BW);
    
    //ERODE AFTERWARDS?*********************************
    
    Mat output_lungs;
    src_image.copyTo(output_lungs, red_BW);
    
    return output_lungs;
}

@end

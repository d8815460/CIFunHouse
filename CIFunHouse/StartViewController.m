//
//  StartViewController.m
//  SquareCam 
//
//  Created by 駿逸 陳 on 2015/4/14.
//
//

#import "StartViewController.h"

@interface StartViewController ()

@end

@implementation StartViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    [self.startBtn.layer setCornerRadius:15.0f];
    
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

//- (void)dealloc {
//    [_startBtn release];
//    [super dealloc];
//}
- (void)viewDidUnload {
    [self setStartBtn:nil];
    [super viewDidUnload];
}
- (IBAction)startBtnPressed:(id)sender {
}
@end

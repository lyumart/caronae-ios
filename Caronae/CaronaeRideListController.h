#import <UIKit/UIKit.h>

@interface CaronaeRideListController : UIViewController

@property (nonatomic) NSArray *rides;
@property (nonatomic) Ride *selectedRide;

@property (nonatomic) BOOL ridesDirectionGoing;

@property (weak, nonatomic) IBOutlet UITableView *tableView;
@property (nonatomic, strong) id<UITableViewDelegate> delegate;
@property (nonatomic, strong) id<UITableViewDataSource> dataSource;
@property (nonatomic, strong) UIRefreshControl *refreshControl;
@property (weak, nonatomic) IBOutlet UISegmentedControl *directionControl;

@property (nonatomic) UILabel *emptyTableLabel;
@property (nonatomic) UILabel *errorLabel;
@property (nonatomic) UILabel *loadingLabel;

@property (nonatomic) IBInspectable BOOL historyTable;

@end
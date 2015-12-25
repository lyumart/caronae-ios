#import <AFNetworking/AFNetworking.h>
#import <SDWebImage/UIImageView+WebCache.h>
#import "RideViewController.h"
#import "CaronaeJoinRequestCell.h"
#import "ProfileViewController.h"
#import "Ride.h"
#import "CaronaeRiderCell.h"
#import "CaronaeAlertController.h"

@interface RideViewController () <UITableViewDelegate, UITableViewDataSource, UICollectionViewDelegate, UICollectionViewDataSource, JoinRequestDelegate, UIGestureRecognizerDelegate>
@property (nonatomic) UIColor *color;

// Ride info
@property (weak, nonatomic) IBOutlet UILabel *titleLabel;
@property (weak, nonatomic) IBOutlet UIImageView *driverPhoto;
@property (weak, nonatomic) IBOutlet UILabel *slotsLabel;
@property (weak, nonatomic) IBOutlet UILabel *dateLabel;
@property (weak, nonatomic) IBOutlet UILabel *descriptionLabel;
@property (weak, nonatomic) IBOutlet UILabel *driverNameLabel;
@property (weak, nonatomic) IBOutlet UILabel *driverCourseLabel;
@property (weak, nonatomic) IBOutlet UILabel *mutualFriendsLabel;
@property (weak, nonatomic) IBOutlet UILabel *driverMessageLabel;
@property (weak, nonatomic) IBOutlet UILabel *routeLabel;
@property (weak, nonatomic) IBOutlet UIView *carDetailsView;
@property (weak, nonatomic) IBOutlet UILabel *carPlateLabel;
@property (weak, nonatomic) IBOutlet UILabel *carModelLabel;
@property (weak, nonatomic) IBOutlet UILabel *carColorLabel;

// Assets
@property (weak, nonatomic) IBOutlet UIView *headerView;
@property (weak, nonatomic) IBOutlet UIView *ridersView;
@property (weak, nonatomic) IBOutlet UIView *mutualFriendsView;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *mutualFriendsCollectionHeight;
@property (weak, nonatomic) IBOutlet UIView *finishRideView;
@property (weak, nonatomic) IBOutlet UICollectionView *ridersCollectionView;
@property (weak, nonatomic) IBOutlet UICollectionView *mutualFriendsCollectionView;
@property (weak, nonatomic) IBOutlet UIImageView *clockIcon;
@property (weak, nonatomic) IBOutlet UIImageView *carIconPlate;
@property (weak, nonatomic) IBOutlet UIImageView *carIconModel;
@property (weak, nonatomic) IBOutlet UIImageView *carIconColor;
@property (weak, nonatomic) IBOutlet UITableView *requestsTable;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *requestsTableHeight;

// Buttons
@property (weak, nonatomic) IBOutlet UIButton *requestRideButton;
@property (weak, nonatomic) IBOutlet UIButton *cancelButton;
@property (weak, nonatomic) IBOutlet UIButton *finishRideButton;

@property (nonatomic) NSArray *joinRequests;
@property (nonatomic) NSDictionary *selectedUser;
@property (nonatomic) NSArray *mutualFriends;
@end

@implementation RideViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.title = @"Carona";
    
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    dateFormatter.dateFormat = @"HH:mm | dd/MM";
    
    NSString *rideTitle = [NSString stringWithFormat:@"%@ → %@", _ride.neighborhood, _ride.hub];
    _titleLabel.text = [rideTitle uppercaseString];
    _dateLabel.text = [NSString stringWithFormat:@"Chegando às %@", [dateFormatter stringFromDate:_ride.date]];
    _slotsLabel.text = [NSString stringWithFormat:@"%d %@", _ride.slots, _ride.slots == 1 ? @"vaga" : @"vagas"];
    _driverNameLabel.text = _ride.driver[@"name"];
    _driverCourseLabel.text = _ride.driver[@"course"];
    _routeLabel.text = [[_ride.route stringByReplacingOccurrencesOfString:@", " withString:@"\n"] stringByReplacingOccurrencesOfString:@"," withString:@"\n"];
    
    if ([_ride.notes isKindOfClass:[NSString class]] && [_ride.notes isEqualToString:@""]) {
        _driverMessageLabel.text = @"---";
    }
    else {
        _driverMessageLabel.text = _ride.notes;
    }
    
    if (_ride.driver[@"profile_pic_url"] && [_ride.driver[@"profile_pic_url"] isKindOfClass:[NSString class]] && ![_ride.driver[@"profile_pic_url"] isEqualToString:@""]) {
        [_driverPhoto sd_setImageWithURL:[NSURL URLWithString:_ride.driver[@"profile_pic_url"]]
                  placeholderImage:[UIImage imageNamed:@"Profile Picture"]
                           options:SDWebImageRefreshCached];
    }
    
    self.color = [CaronaeDefaults colorForZone:_ride.zone];
    
    UINib *cellNib = [UINib nibWithNibName:@"CaronaeJoinRequestCell" bundle:nil];
    [self.requestsTable registerNib:cellNib forCellReuseIdentifier:@"Request Cell"];
    self.requestsTable.dataSource = self;
    self.requestsTable.delegate = self;
    self.requestsTable.rowHeight = 95.0f;
    self.requestsTableHeight.constant = 0;
    
    // If the user is the driver of the ride, load pending join requests and hide 'join' button
    if ([self userIsDriver]) {
        [self searchForJoinRequests];
        [self.requestRideButton performSelectorOnMainThread:@selector(removeFromSuperview) withObject:nil waitUntilDone:NO];
        [self.mutualFriendsView performSelectorOnMainThread:@selector(removeFromSuperview) withObject:nil waitUntilDone:NO];
        
        // Car details
        NSDictionary *user = [CaronaeDefaults defaults].user;
        _carPlateLabel.text = user[@"car_plate"];
        _carModelLabel.text = user[@"car_model"];
        _carColorLabel.text = user[@"car_color"];
    }
    // If the user is already a rider, hide 'join' button
    else if ([self userIsRider]) {
        [self.requestRideButton performSelectorOnMainThread:@selector(removeFromSuperview) withObject:nil waitUntilDone:NO];
        [self.finishRideView performSelectorOnMainThread:@selector(removeFromSuperview) withObject:nil waitUntilDone:NO];
        [self.cancelButton setTitle:@"DESISTIR" forState:UIControlStateNormal];
        
        // Car details
        _carPlateLabel.text = _ride.driver[@"car_plate"];
        _carModelLabel.text = _ride.driver[@"car_model"];
        _carColorLabel.text = _ride.driver[@"car_color"];
        
        [self updateMutualFriends];
    }
    // If the user is not related to the ride, hide 'cancel' button, car details view and riders view
    else {
        [self.cancelButton performSelectorOnMainThread:@selector(removeFromSuperview) withObject:nil waitUntilDone:NO];
        [self.carDetailsView performSelectorOnMainThread:@selector(removeFromSuperview) withObject:nil waitUntilDone:NO];
        [self.finishRideView performSelectorOnMainThread:@selector(removeFromSuperview) withObject:nil waitUntilDone:NO];
        
        [self updateMutualFriends];
    }
    
    // If the riders aren't provided then hide the riders view
    if (!_ride.users) {
        [self.ridersView performSelectorOnMainThread:@selector(removeFromSuperview) withObject:nil waitUntilDone:NO];
    }
}

- (void)setColor:(UIColor *)color {
    _color = color;
    _headerView.backgroundColor = color;
    _clockIcon.tintColor = color;
    _dateLabel.textColor = color;
    _driverPhoto.layer.borderColor = color.CGColor;
    _carIconPlate.tintColor = color;
    _carIconModel.tintColor = color;
    _carIconColor.tintColor = color;
}

- (BOOL)userIsDriver {
    return [[CaronaeDefaults defaults].user[@"id"] isEqual:_ride.driver[@"id"]];
}

- (BOOL)userIsRider {
    for (NSDictionary *user in _ride.users) {
        if ([user[@"id"] isEqual:[CaronaeDefaults defaults].user[@"id"]]) {
            return YES;
        }
    }
    return NO;
}

- (void)updateMutualFriends {
    // Abort if the Facebook accounts are not connected.
    if (![CaronaeDefaults userFBToken] || ![_ride.driver[@"face_id"] isKindOfClass:[NSString class]] || [_ride.driver[@"face_id"] isEqualToString:@""]) {
        return;
    }
    
    AFHTTPRequestOperationManager *manager = [AFHTTPRequestOperationManager manager];
    manager.requestSerializer = [AFJSONRequestSerializer serializer];
    [manager.requestSerializer setValue:[CaronaeDefaults defaults].userToken forHTTPHeaderField:@"token"];
    [manager.requestSerializer setValue:[CaronaeDefaults userFBToken] forHTTPHeaderField:@"Facebook-Token"];
    
    [manager GET:[CaronaeAPIBaseURL stringByAppendingString:[NSString stringWithFormat:@"/user/%@/mutualFriends", _ride.driver[@"face_id"]]] parameters:nil success:^(AFHTTPRequestOperation *operation, id responseObject) {
        NSArray *mutualFriends = responseObject[@"mutual_friends"];
        if (mutualFriends.count > 0) {
            [_mutualFriendsView layoutIfNeeded];
            _mutualFriendsCollectionHeight.constant = 40.0f;
            [UIView animateWithDuration:0.5 animations:^{
                [_mutualFriendsView layoutIfNeeded];
            }];
            _mutualFriends = mutualFriends;
            [_mutualFriendsCollectionView reloadData];
        }
        _mutualFriendsLabel.text = [NSString stringWithFormat:@"Amigos em comum: %d", [responseObject[@"total_count"] intValue]];
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        NSLog(@"Error loading mutual friends for user: %@", error.localizedDescription);
    }];
}


#pragma mark - Navigation

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.identifier isEqualToString:@"ViewProfile"]) {
        ProfileViewController *vc = segue.destinationViewController;
        vc.user = self.selectedUser;
    }
}


#pragma mark - IBActions

- (IBAction)didTapRequestRide:(UIButton *)sender {
    [self requestJoinRide];
}

- (IBAction)viewUserProfile:(id)sender {
    self.selectedUser = _ride.driver;
    [self performSegueWithIdentifier:@"ViewProfile" sender:self];
}

- (IBAction)didTapCancelRide:(id)sender {
    CaronaeAlertController *alert = [CaronaeAlertController alertControllerWithTitle:@"Deseja mesmo desistir da carona?"
                                                                             message:@"Você é livre para cancelar caronas caso não possa participar, mas é importante fazer isso com responsabilidade. Os outros usuários da carona serão notificados."
                                                                      preferredStyle:SDCAlertControllerStyleAlert];
    [alert addAction:[SDCAlertAction actionWithTitle:@"Cancelar" style:SDCAlertActionStyleCancel handler:nil]];
    [alert addAction:[SDCAlertAction actionWithTitle:@"Desistir" style:SDCAlertActionStyleDestructive handler:^(SDCAlertAction *action){
        [self cancelRide];
    }]];
    [alert presentWithCompletion:nil];
}

- (IBAction)didTapFinishRide:(id)sender {
    CaronaeAlertController *alert = [CaronaeAlertController alertControllerWithTitle:@"Concluir carona"
                                                                             message:@"E aí? Correu tudo bem? Deseja mesmo concluir a carona?"
                                                                      preferredStyle:SDCAlertControllerStyleAlert];
    [alert addAction:[SDCAlertAction actionWithTitle:@"Cancelar" style:SDCAlertActionStyleCancel handler:nil]];
    [alert addAction:[SDCAlertAction actionWithTitle:@"Concluir" style:SDCAlertActionStyleDefault handler:^(SDCAlertAction *action){
        [self finishRide];
    }]];
    [alert presentWithCompletion:nil];
}


#pragma mark - Ride operations

- (void)cancelRide {
    NSLog(@"Requesting to leave ride %ld", _ride.rideID);
    
    AFHTTPRequestOperationManager *manager = [AFHTTPRequestOperationManager manager];
    manager.requestSerializer = [AFJSONRequestSerializer serializer];
    [manager.requestSerializer setValue:[CaronaeDefaults defaults].userToken forHTTPHeaderField:@"token"];
    NSDictionary *params = @{@"rideId": @(_ride.rideID)};
    
    _cancelButton.enabled = NO;
    
    [manager POST:[CaronaeAPIBaseURL stringByAppendingString:@"/ride/leaveRide"] parameters:params success:^(AFHTTPRequestOperation *operation, id responseObject) {
        NSLog(@"User left the ride. (Message: %@)", responseObject[@"message"]);
        
        if ([_delegate respondsToSelector:@selector(didDeleteRide:)]) {
            [_delegate didDeleteRide:_ride];
        }
        
        [self.navigationController popViewControllerAnimated:YES];
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        NSLog(@"Error: %@", error.description);
        _cancelButton.enabled = YES;
    }];
}

- (void)finishRide {
    NSLog(@"Requesting to finish ride %ld", _ride.rideID);
    
    AFHTTPRequestOperationManager *manager = [AFHTTPRequestOperationManager manager];
    manager.requestSerializer = [AFJSONRequestSerializer serializer];
    [manager.requestSerializer setValue:[CaronaeDefaults defaults].userToken forHTTPHeaderField:@"token"];
    NSDictionary *params = @{@"rideId": @(_ride.rideID)};
    
    _finishRideButton.enabled = NO;
    
    [manager POST:[CaronaeAPIBaseURL stringByAppendingString:@"/ride/finishRide"] parameters:params success:^(AFHTTPRequestOperation *operation, id responseObject) {
        NSLog(@"User finished the ride. (Message: %@)", responseObject[@"message"]);
        
        [_finishRideButton setTitle:@"  Carona concluída" forState:UIControlStateNormal];
        [self.cancelButton performSelectorOnMainThread:@selector(removeFromSuperview) withObject:nil waitUntilDone:NO];
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        NSLog(@"Error: %@", error.description);
        _finishRideButton.enabled = YES;
    }];
}


#pragma mark - Join request methods

- (void)requestJoinRide {
    NSLog(@"Requesting to join ride %ld", _ride.rideID);
    NSDictionary *params = @{@"rideId": @(_ride.rideID)};
    
    AFHTTPRequestOperationManager *manager = [AFHTTPRequestOperationManager manager];
    manager.requestSerializer = [AFJSONRequestSerializer serializer];
    [manager.requestSerializer setValue:[CaronaeDefaults defaults].userToken forHTTPHeaderField:@"token"];
    
    _requestRideButton.enabled = NO;
    
    [manager POST:[CaronaeAPIBaseURL stringByAppendingString:@"/ride/requestJoin"] parameters:params success:^(AFHTTPRequestOperation *operation, id responseObject) {
        NSLog(@"Done requesting ride.");
        [_requestRideButton setTitle:@"    AGUARDANDO AUTORIZAÇÃO    " forState:UIControlStateNormal];
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        NSLog(@"Error: %@", error.description);
        _requestRideButton.enabled = YES;
    }];
}

- (void)searchForJoinRequests {
    long rideID = _ride.rideID;
    
    AFHTTPRequestOperationManager *manager = [AFHTTPRequestOperationManager manager];
    manager.requestSerializer = [AFJSONRequestSerializer serializer];
    [manager.requestSerializer setValue:[CaronaeDefaults defaults].userToken forHTTPHeaderField:@"token"];
    
    //    [self showLoadingHUD:YES];
    
    [manager GET:[CaronaeAPIBaseURL stringByAppendingString:[NSString stringWithFormat:@"/ride/getRequesters/%ld", rideID]] parameters:nil success:^(AFHTTPRequestOperation *operation, id responseObject) {
        //        [self showLoadingHUD:NO];
        
        NSLog(@"Results for join requests are back.");
        
        NSError *responseError;
        NSArray *joinRequests = [RideViewController parseJoinRequestsFromResponse:responseObject withError:&responseError];
        if (!responseError) {
            NSLog(@"Search returned %lu join requests.", (unsigned long)joinRequests.count);
            self.joinRequests = joinRequests;
            if (joinRequests.count > 0) {
                [self.requestsTable reloadData];
                [self adjustHeightOfTableview];
            }
        }
        
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        //        [self showLoadingHUD:NO];
        NSLog(@"Error: %@", error.description);
    }];
    
}

+ (NSArray *)parseJoinRequestsFromResponse:(id)responseObject withError:(NSError *__autoreleasing *)err {
    // Check if we received an array of the rides
    if ([responseObject isKindOfClass:NSArray.class]) {
        return responseObject;
    }
    else {
        if (err) {
            NSDictionary *errorInfo = @{
                                        NSLocalizedDescriptionKey: NSLocalizedString(@"Unexpected server response.", nil)
                                        };
            *err = [NSError errorWithDomain:CaronaeErrorDomain code:CaronaeErrorInvalidResponse userInfo:errorInfo];
        }
    }
    
    return nil;
}

- (void)joinRequest:(NSDictionary *)request hasAccepted:(BOOL)accepted {
    NSLog(@"Request for user %@ was %@", request[@"name"], accepted ? @"accepted" : @"not accepted");
    NSDictionary *params = @{@"userId": request[@"id"],
                             @"rideId": @(_ride.rideID),
                             @"accepted": @(accepted)};
    
    AFHTTPRequestOperationManager *manager = [AFHTTPRequestOperationManager manager];
    manager.requestSerializer = [AFJSONRequestSerializer serializer];
    [manager.requestSerializer setValue:[CaronaeDefaults defaults].userToken forHTTPHeaderField:@"token"];
    
    [manager POST:[CaronaeAPIBaseURL stringByAppendingString:@"/ride/answerJoinRequest"] parameters:params success:^(AFHTTPRequestOperation *operation, id responseObject) {
        NSLog(@"Answer to join request successfully sent.");
        [self removeJoinRequest:request];
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        NSLog(@"Error: %@", error.description);
    }];
}

- (void)removeJoinRequest:(NSDictionary *)request {
    NSMutableArray *joinRequestsMutable = [NSMutableArray arrayWithArray:self.joinRequests];
    [joinRequestsMutable removeObject:request];
    
    [self.requestsTable beginUpdates];
    unsigned long index = [self.joinRequests indexOfObject:request];
    [self.requestsTable deleteRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:index inSection:0]] withRowAnimation:UITableViewRowAnimationAutomatic];
    self.joinRequests = joinRequestsMutable;
    [self.requestsTable endUpdates];
    [self adjustHeightOfTableview];
}

- (void)tappedUserDetailsForRequest:(NSDictionary *)request {
    self.selectedUser = request;
    [self performSegueWithIdentifier:@"ViewProfile" sender:self];
}


#pragma mark - Table methods

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.joinRequests.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    CaronaeJoinRequestCell *cell = [tableView dequeueReusableCellWithIdentifier:@"Request Cell" forIndexPath:indexPath];
    
    cell.delegate = self;
    [cell configureCellWithRequest:self.joinRequests[indexPath.row]];
    
    return cell;
}

- (void)adjustHeightOfTableview {
    [self.view layoutIfNeeded];
    CGFloat height = self.requestsTable.contentSize.height;
    self.requestsTableHeight.constant = height;
    [UIView animateWithDuration:0.25 animations:^{
        [self.view layoutIfNeeded];
    }];
}


#pragma mark - Collection methods (Riders)

- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView {
    return 1;
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    if (collectionView == _ridersCollectionView) {
        return _ride.users.count;
    }
    else {
        return _mutualFriends.count;
    }
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    CaronaeRiderCell *cell;
    NSDictionary *user;
    
    if (collectionView == _ridersCollectionView) {
        user = _ride.users[indexPath.row];
        cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"Rider Cell" forIndexPath:indexPath];
    }
    else {
        user = _mutualFriends[indexPath.row];
        cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"Friend Cell" forIndexPath:indexPath];
        
    }
    
    NSString *firstName = [user[@"name"] componentsSeparatedByString:@" "].firstObject;
    cell.user = user;
    cell.nameLabel.text = firstName;
    
    if (user[@"profile_pic_url"] && [user[@"profile_pic_url"] isKindOfClass:[NSString class]] && ![user[@"profile_pic_url"] isEqualToString:@""]) {
        [cell.photo sd_setImageWithURL:[NSURL URLWithString:user[@"profile_pic_url"]]
                      placeholderImage:[UIImage imageNamed:@"Profile Picture"]
                               options:SDWebImageRefreshCached];
    }
    
    return cell;
}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    [collectionView deselectItemAtIndexPath:indexPath animated:YES];
    
    if (collectionView == _ridersCollectionView) {
        CaronaeRiderCell *cell = (CaronaeRiderCell *)[collectionView cellForItemAtIndexPath:indexPath];
        self.selectedUser = cell.user;
        
        [self performSegueWithIdentifier:@"ViewProfile" sender:self];
    }
}

@end

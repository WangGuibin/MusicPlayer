//
//  MusicSettingsViewController.m
//  VodTV
//
//  Created by Claude on 2025/9/6.
//

#import "MusicSettingsViewController.h"
#import "MusicSettingsManager.h"
#import "Masonry.h"

@interface MusicSettingsViewController () <UITableViewDelegate, UITableViewDataSource>

@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) MusicSettingsManager *settingsManager;
@property (nonatomic, strong) NSArray<NSString *> *sectionTitles;
@property (nonatomic, strong) NSArray<NSArray<NSString *> *> *menuItems;

@end

@implementation MusicSettingsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.title = @"音乐设置";
    self.view.backgroundColor = [UIColor systemBackgroundColor];
    
    [self setupData];
    [self setupUI];
    [self setupConstraints];
    [self setupNavigationBar];
}

- (void)setupData {
    self.settingsManager = [MusicSettingsManager sharedManager];
    
    self.sectionTitles = @[@"默认音乐源", @"全局音质"];
    self.menuItems = @[
        @[@"音乐源选择"],
        @[@"音质选择"]
    ];
}

- (void)setupUI {
    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleInsetGrouped];
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    self.tableView.backgroundColor = [UIColor systemGroupedBackgroundColor];
    [self.view addSubview:self.tableView];
}

- (void)setupConstraints {
    [self.tableView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.equalTo(self.view);
    }];
}

- (void)setupNavigationBar {
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemClose target:self action:@selector(closeButtonTapped)];
}

#pragma mark - Actions

- (void)closeButtonTapped {
    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - UITableView DataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return self.sectionTitles.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.menuItems[section].count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *cellIdentifier = @"SettingsCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:cellIdentifier];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }
    
    NSString *title = self.menuItems[indexPath.section][indexPath.row];
    cell.textLabel.text = title;
    
    if (indexPath.section == 0) {
        // 音乐源选择
        cell.detailTextLabel.text = [self.settingsManager sourceDisplayNameForSource:self.settingsManager.defaultSource];
    } else if (indexPath.section == 1) {
        // 音质选择
        cell.detailTextLabel.text = [self.settingsManager qualityDisplayNameForQuality:self.settingsManager.globalQuality];
    }
    
    return cell;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return self.sectionTitles[section];
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    if (section == 0) {
        return @"选择默认的音乐搜索源，支持网易云音乐、酷我音乐和JOOX音乐";
    } else if (section == 1) {
        return @"选择全局音质，740和999为无损音质";
    }
    return nil;
}

#pragma mark - UITableView Delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    if (indexPath.section == 0) {
        [self showSourceSelectionAlert];
    } else if (indexPath.section == 1) {
        [self showQualitySelectionAlert];
    }
}

#pragma mark - Alert Methods

- (void)showSourceSelectionAlert {
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"选择音乐源" 
                                                                             message:@"请选择默认的音乐搜索源" 
                                                                      preferredStyle:UIAlertControllerStyleActionSheet];
    
    NSArray<NSNumber *> *sources = [self.settingsManager availableSourceOptions];
    for (NSNumber *sourceNumber in sources) {
        MusicSource source = (MusicSource)[sourceNumber integerValue];
        NSString *displayName = [self.settingsManager sourceDisplayNameForSource:source];
        
        UIAlertAction *action = [UIAlertAction actionWithTitle:displayName 
                                                         style:UIAlertActionStyleDefault 
                                                       handler:^(UIAlertAction * _Nonnull action) {
            self.settingsManager.defaultSource = source;
            [self.tableView reloadData];
        }];
        
        if (source == self.settingsManager.defaultSource) {
            [action setValue:[UIImage systemImageNamed:@"checkmark"] forKey:@"image"];
        }
        
        [alertController addAction:action];
    }
    
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"取消" 
                                                           style:UIAlertActionStyleCancel 
                                                         handler:nil];
    [alertController addAction:cancelAction];
    
    // For iPad
    if (alertController.popoverPresentationController) {
        alertController.popoverPresentationController.sourceView = self.view;
        alertController.popoverPresentationController.sourceRect = CGRectMake(self.view.bounds.size.width/2.0, self.view.bounds.size.height/2.0, 1.0, 1.0);
    }
    
    [self presentViewController:alertController animated:YES completion:nil];
}

- (void)showQualitySelectionAlert {
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"选择音质" 
                                                                             message:@"请选择全局音质设置" 
                                                                      preferredStyle:UIAlertControllerStyleActionSheet];
    
    NSArray<NSNumber *> *qualities = [self.settingsManager availableQualityOptions];
    for (NSNumber *qualityNumber in qualities) {
        MusicQuality quality = (MusicQuality)[qualityNumber integerValue];
        NSString *displayName = [self.settingsManager qualityDisplayNameForQuality:quality];
        
        UIAlertAction *action = [UIAlertAction actionWithTitle:displayName 
                                                         style:UIAlertActionStyleDefault 
                                                       handler:^(UIAlertAction * _Nonnull action) {
            self.settingsManager.globalQuality = quality;
            [self.tableView reloadData];
        }];
        
        if (quality == self.settingsManager.globalQuality) {
            [action setValue:[UIImage systemImageNamed:@"checkmark"] forKey:@"image"];
        }
        
        [alertController addAction:action];
    }
    
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"取消" 
                                                           style:UIAlertActionStyleCancel 
                                                         handler:nil];
    [alertController addAction:cancelAction];
    
    // For iPad
    if (alertController.popoverPresentationController) {
        alertController.popoverPresentationController.sourceView = self.view;
        alertController.popoverPresentationController.sourceRect = CGRectMake(self.view.bounds.size.width/2.0, self.view.bounds.size.height/2.0, 1.0, 1.0);
    }
    
    [self presentViewController:alertController animated:YES completion:nil];
}

@end
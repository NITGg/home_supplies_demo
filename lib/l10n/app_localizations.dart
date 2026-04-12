import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en')
  ];

  /// No description provided for @next.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get next;

  /// No description provided for @prev.
  ///
  /// In en, this message translates to:
  /// **'Previous'**
  String get prev;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @skip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get skip;

  /// No description provided for @profile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profile;

  /// No description provided for @menu.
  ///
  /// In en, this message translates to:
  /// **'Menu'**
  String get menu;

  /// No description provided for @welcome.
  ///
  /// In en, this message translates to:
  /// **'Welcome'**
  String get welcome;

  /// No description provided for @tawreedatIsYourBestChoice.
  ///
  /// In en, this message translates to:
  /// **'Tawreedat Is Your Best Choice'**
  String get tawreedatIsYourBestChoice;

  /// No description provided for @lang.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get lang;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @support.
  ///
  /// In en, this message translates to:
  /// **'Support'**
  String get support;

  /// No description provided for @faq.
  ///
  /// In en, this message translates to:
  /// **'FAQ'**
  String get faq;

  /// No description provided for @privecyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get privecyPolicy;

  /// No description provided for @termsAndConditions.
  ///
  /// In en, this message translates to:
  /// **'Terms and Conditions'**
  String get termsAndConditions;

  /// No description provided for @logout.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get logout;

  /// No description provided for @signin.
  ///
  /// In en, this message translates to:
  /// **'Sign In'**
  String get signin;

  /// No description provided for @register.
  ///
  /// In en, this message translates to:
  /// **'Register'**
  String get register;

  /// No description provided for @email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @confirmPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm Password'**
  String get confirmPassword;

  /// No description provided for @phone.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get phone;

  /// No description provided for @firstName.
  ///
  /// In en, this message translates to:
  /// **'First Name'**
  String get firstName;

  /// No description provided for @lastName.
  ///
  /// In en, this message translates to:
  /// **'Last Name'**
  String get lastName;

  /// No description provided for @forgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot Password?'**
  String get forgotPassword;

  /// No description provided for @orSignInwith.
  ///
  /// In en, this message translates to:
  /// **'Or sign in with'**
  String get orSignInwith;

  /// No description provided for @orRegisterwith.
  ///
  /// In en, this message translates to:
  /// **'Or register with'**
  String get orRegisterwith;

  /// No description provided for @dontHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account?'**
  String get dontHaveAccount;

  /// No description provided for @haveAccount.
  ///
  /// In en, this message translates to:
  /// **'Already have an account?'**
  String get haveAccount;

  /// No description provided for @points.
  ///
  /// In en, this message translates to:
  /// **'Points'**
  String get points;

  /// No description provided for @point.
  ///
  /// In en, this message translates to:
  /// **'Point'**
  String get point;

  /// No description provided for @extraPhone.
  ///
  /// In en, this message translates to:
  /// **'Extra Phone'**
  String get extraPhone;

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// No description provided for @searchFor.
  ///
  /// In en, this message translates to:
  /// **'search for a place, address, landmark....'**
  String get searchFor;

  /// No description provided for @showAll.
  ///
  /// In en, this message translates to:
  /// **'Show All'**
  String get showAll;

  /// No description provided for @show_All.
  ///
  /// In en, this message translates to:
  /// **'Show All'**
  String get show_All;

  /// No description provided for @selectDate.
  ///
  /// In en, this message translates to:
  /// **'Select Date'**
  String get selectDate;

  /// No description provided for @to.
  ///
  /// In en, this message translates to:
  /// **'To'**
  String get to;

  /// No description provided for @from.
  ///
  /// In en, this message translates to:
  /// **'From'**
  String get from;

  /// No description provided for @today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get today;

  /// No description provided for @thisWeek.
  ///
  /// In en, this message translates to:
  /// **'This Week'**
  String get thisWeek;

  /// No description provided for @thisMonth.
  ///
  /// In en, this message translates to:
  /// **'This Month'**
  String get thisMonth;

  /// No description provided for @lastMonth.
  ///
  /// In en, this message translates to:
  /// **'Last Month'**
  String get lastMonth;

  /// No description provided for @custom.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get custom;

  /// No description provided for @filterBy.
  ///
  /// In en, this message translates to:
  /// **'Filter By'**
  String get filterBy;

  /// No description provided for @filter.
  ///
  /// In en, this message translates to:
  /// **'Filter'**
  String get filter;

  /// No description provided for @groups.
  ///
  /// In en, this message translates to:
  /// **'Categories'**
  String get groups;

  /// No description provided for @packageDetails.
  ///
  /// In en, this message translates to:
  /// **'PackageDetails'**
  String get packageDetails;

  /// No description provided for @myPersonalInfo.
  ///
  /// In en, this message translates to:
  /// **'My Personal Info'**
  String get myPersonalInfo;

  /// No description provided for @myInfo.
  ///
  /// In en, this message translates to:
  /// **'My Info'**
  String get myInfo;

  /// No description provided for @address.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get address;

  /// No description provided for @paymentMethod.
  ///
  /// In en, this message translates to:
  /// **'Payment Method'**
  String get paymentMethod;

  /// No description provided for @payNow.
  ///
  /// In en, this message translates to:
  /// **'Pay Now'**
  String get payNow;

  /// No description provided for @cancelOrder.
  ///
  /// In en, this message translates to:
  /// **'Cancel Order'**
  String get cancelOrder;

  /// No description provided for @addWallet.
  ///
  /// In en, this message translates to:
  /// **'Add Wallet'**
  String get addWallet;

  /// No description provided for @notifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// No description provided for @markAllAsRead.
  ///
  /// In en, this message translates to:
  /// **'Mark All as Read'**
  String get markAllAsRead;

  /// No description provided for @clearAll.
  ///
  /// In en, this message translates to:
  /// **'Clear All'**
  String get clearAll;

  /// No description provided for @clear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clear;

  /// No description provided for @paidDate.
  ///
  /// In en, this message translates to:
  /// **'Paid:'**
  String get paidDate;

  /// No description provided for @waivedDate.
  ///
  /// In en, this message translates to:
  /// **'Waived:'**
  String get waivedDate;

  /// No description provided for @paid.
  ///
  /// In en, this message translates to:
  /// **'Paid'**
  String get paid;

  /// No description provided for @waived.
  ///
  /// In en, this message translates to:
  /// **'Waived'**
  String get waived;

  /// No description provided for @viewAll.
  ///
  /// In en, this message translates to:
  /// **'View All'**
  String get viewAll;

  /// No description provided for @escrowHold.
  ///
  /// In en, this message translates to:
  /// **'Escrow Hold'**
  String get escrowHold;

  /// No description provided for @order.
  ///
  /// In en, this message translates to:
  /// **'Order'**
  String get order;

  /// No description provided for @errorOccurred.
  ///
  /// In en, this message translates to:
  /// **'Error Occurred'**
  String get errorOccurred;

  /// No description provided for @deleteAccount.
  ///
  /// In en, this message translates to:
  /// **'Delete Account'**
  String get deleteAccount;

  /// No description provided for @all.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get all;

  /// No description provided for @apply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get apply;

  /// No description provided for @penalty.
  ///
  /// In en, this message translates to:
  /// **'Penalty'**
  String get penalty;

  /// No description provided for @youreInGoodStanding.
  ///
  /// In en, this message translates to:
  /// **'You\'re in good standing!'**
  String get youreInGoodStanding;

  /// No description provided for @withdrawal.
  ///
  /// In en, this message translates to:
  /// **'Withdrawal'**
  String get withdrawal;

  /// No description provided for @failed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get failed;

  /// No description provided for @escrowRelease.
  ///
  /// In en, this message translates to:
  /// **'Escrow Release'**
  String get escrowRelease;

  /// No description provided for @noTransactionsYet.
  ///
  /// In en, this message translates to:
  /// **'No transactions yet'**
  String get noTransactionsYet;

  /// No description provided for @penalties.
  ///
  /// In en, this message translates to:
  /// **'Penalties'**
  String get penalties;

  /// No description provided for @noPenalties.
  ///
  /// In en, this message translates to:
  /// **'No penalties'**
  String get noPenalties;

  /// No description provided for @pendingPenalties.
  ///
  /// In en, this message translates to:
  /// **'Pending Penalties'**
  String get pendingPenalties;

  /// No description provided for @subtotal.
  ///
  /// In en, this message translates to:
  /// **'Subtotal:'**
  String get subtotal;

  /// No description provided for @sum.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get sum;

  /// No description provided for @quantity.
  ///
  /// In en, this message translates to:
  /// **'Quantity'**
  String get quantity;

  /// No description provided for @price.
  ///
  /// In en, this message translates to:
  /// **'Price:'**
  String get price;

  /// No description provided for @newBudget.
  ///
  /// In en, this message translates to:
  /// **'Required Budget:'**
  String get newBudget;

  /// No description provided for @info.
  ///
  /// In en, this message translates to:
  /// **'Info'**
  String get info;

  /// No description provided for @deleteAll.
  ///
  /// In en, this message translates to:
  /// **'Delete All'**
  String get deleteAll;

  /// No description provided for @payment.
  ///
  /// In en, this message translates to:
  /// **'Payment'**
  String get payment;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// No description provided for @continue_.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continue_;

  /// No description provided for @detailsAndAddress.
  ///
  /// In en, this message translates to:
  /// **'Details and Address'**
  String get detailsAndAddress;

  /// No description provided for @name.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get name;

  /// No description provided for @governate.
  ///
  /// In en, this message translates to:
  /// **'Governorate'**
  String get governate;

  /// No description provided for @chooseGovernate.
  ///
  /// In en, this message translates to:
  /// **'Choose Governorate'**
  String get chooseGovernate;

  /// No description provided for @city.
  ///
  /// In en, this message translates to:
  /// **'City'**
  String get city;

  /// No description provided for @state.
  ///
  /// In en, this message translates to:
  /// **'State'**
  String get state;

  /// No description provided for @gettingLocation.
  ///
  /// In en, this message translates to:
  /// **'Getting location'**
  String get gettingLocation;

  /// No description provided for @useCurrentLocation.
  ///
  /// In en, this message translates to:
  /// **'Use current location'**
  String get useCurrentLocation;

  /// No description provided for @pickOnMaps.
  ///
  /// In en, this message translates to:
  /// **'Pick On Map'**
  String get pickOnMaps;

  /// No description provided for @locationObtained.
  ///
  /// In en, this message translates to:
  /// **'Location obtained'**
  String get locationObtained;

  /// No description provided for @postalCode.
  ///
  /// In en, this message translates to:
  /// **'Postal Code'**
  String get postalCode;

  /// No description provided for @apartmentNo.
  ///
  /// In en, this message translates to:
  /// **'Apartment No'**
  String get apartmentNo;

  /// No description provided for @buildingNo.
  ///
  /// In en, this message translates to:
  /// **'Building No'**
  String get buildingNo;

  /// No description provided for @floorNo.
  ///
  /// In en, this message translates to:
  /// **'Floor No'**
  String get floorNo;

  /// No description provided for @updateAddress.
  ///
  /// In en, this message translates to:
  /// **'Update Address'**
  String get updateAddress;

  /// No description provided for @permissionDenied.
  ///
  /// In en, this message translates to:
  /// **'Permission Denied'**
  String get permissionDenied;

  /// No description provided for @saveInvoice.
  ///
  /// In en, this message translates to:
  /// **'Save Invoice'**
  String get saveInvoice;

  /// No description provided for @chooseArea.
  ///
  /// In en, this message translates to:
  /// **'Choose Area'**
  String get chooseArea;

  /// No description provided for @areasSelected.
  ///
  /// In en, this message translates to:
  /// **'Areas Selected'**
  String get areasSelected;

  /// No description provided for @uploading.
  ///
  /// In en, this message translates to:
  /// **'uploading...'**
  String get uploading;

  /// No description provided for @detailedAddress.
  ///
  /// In en, this message translates to:
  /// **'Detailed Address'**
  String get detailedAddress;

  /// No description provided for @saveAddress.
  ///
  /// In en, this message translates to:
  /// **'Save Address'**
  String get saveAddress;

  /// No description provided for @addAddress.
  ///
  /// In en, this message translates to:
  /// **'Add Address'**
  String get addAddress;

  /// No description provided for @deletingAccountWill.
  ///
  /// In en, this message translates to:
  /// **'Deleting your account will remove all your data'**
  String get deletingAccountWill;

  /// No description provided for @areYouSureDeleteAccount.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete your account?'**
  String get areYouSureDeleteAccount;

  /// No description provided for @areYouSureDelete.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete?'**
  String get areYouSureDelete;

  /// No description provided for @closeApp.
  ///
  /// In en, this message translates to:
  /// **'Close App'**
  String get closeApp;

  /// No description provided for @accountDeletedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Account deleted successfully'**
  String get accountDeletedSuccess;

  /// No description provided for @changePassword.
  ///
  /// In en, this message translates to:
  /// **'Change Password'**
  String get changePassword;

  /// No description provided for @loginData.
  ///
  /// In en, this message translates to:
  /// **'Login Data'**
  String get loginData;

  /// No description provided for @noData.
  ///
  /// In en, this message translates to:
  /// **'No Data'**
  String get noData;

  /// No description provided for @enterPhoneNumber.
  ///
  /// In en, this message translates to:
  /// **'Enter phone number'**
  String get enterPhoneNumber;

  /// No description provided for @invalidPhoneNumber.
  ///
  /// In en, this message translates to:
  /// **'Invalid phone number'**
  String get invalidPhoneNumber;

  /// No description provided for @enterPassword.
  ///
  /// In en, this message translates to:
  /// **'Enter password'**
  String get enterPassword;

  /// No description provided for @shortPassword.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 8 characters'**
  String get shortPassword;

  /// No description provided for @invalidEmail.
  ///
  /// In en, this message translates to:
  /// **'Invalid email'**
  String get invalidEmail;

  /// No description provided for @passwordMismatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match'**
  String get passwordMismatch;

  /// No description provided for @weNeedYourPhoneNumber.
  ///
  /// In en, this message translates to:
  /// **'We need your phone number'**
  String get weNeedYourPhoneNumber;

  /// No description provided for @maybeLater.
  ///
  /// In en, this message translates to:
  /// **'Maybe later'**
  String get maybeLater;

  /// No description provided for @profileUpdatedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Profile updated successfully'**
  String get profileUpdatedSuccessfully;

  /// No description provided for @updateProfile.
  ///
  /// In en, this message translates to:
  /// **'Update Profile'**
  String get updateProfile;

  /// No description provided for @chooseImageSource.
  ///
  /// In en, this message translates to:
  /// **'Choose image source'**
  String get chooseImageSource;

  /// No description provided for @camera.
  ///
  /// In en, this message translates to:
  /// **'Camera'**
  String get camera;

  /// No description provided for @gallery.
  ///
  /// In en, this message translates to:
  /// **'Gallery'**
  String get gallery;

  /// No description provided for @failedToChooseImage.
  ///
  /// In en, this message translates to:
  /// **'Failed to choose image: '**
  String get failedToChooseImage;

  /// No description provided for @failedToCropImage.
  ///
  /// In en, this message translates to:
  /// **'Failed to crop image: '**
  String get failedToCropImage;

  /// No description provided for @cropImage.
  ///
  /// In en, this message translates to:
  /// **'Crop Image'**
  String get cropImage;

  /// No description provided for @oldPassword.
  ///
  /// In en, this message translates to:
  /// **'Current Password'**
  String get oldPassword;

  /// No description provided for @weight.
  ///
  /// In en, this message translates to:
  /// **'Weight'**
  String get weight;

  /// No description provided for @emptySearch.
  ///
  /// In en, this message translates to:
  /// **'Empty Search'**
  String get emptySearch;

  /// No description provided for @nothingSearched.
  ///
  /// In en, this message translates to:
  /// **'Nothing searched'**
  String get nothingSearched;

  /// No description provided for @noResultsFound.
  ///
  /// In en, this message translates to:
  /// **'No results found'**
  String get noResultsFound;

  /// No description provided for @reviews.
  ///
  /// In en, this message translates to:
  /// **'Reviews'**
  String get reviews;

  /// No description provided for @addReview.
  ///
  /// In en, this message translates to:
  /// **'What do you think about this product?'**
  String get addReview;

  /// No description provided for @reviewSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Review submitted'**
  String get reviewSubmitted;

  /// No description provided for @reviewError.
  ///
  /// In en, this message translates to:
  /// **'Error: Review not submitted. Try again later'**
  String get reviewError;

  /// No description provided for @googleSignin.
  ///
  /// In en, this message translates to:
  /// **'Google Account'**
  String get googleSignin;

  /// No description provided for @appleSignin.
  ///
  /// In en, this message translates to:
  /// **'Apple Account'**
  String get appleSignin;

  /// No description provided for @offers.
  ///
  /// In en, this message translates to:
  /// **'offers'**
  String get offers;

  /// No description provided for @upTo.
  ///
  /// In en, this message translates to:
  /// **'Up to'**
  String get upTo;

  /// No description provided for @noFavourites.
  ///
  /// In en, this message translates to:
  /// **'No favorites yet'**
  String get noFavourites;

  /// No description provided for @addToFavourites.
  ///
  /// In en, this message translates to:
  /// **'Start adding products to favorites'**
  String get addToFavourites;

  /// No description provided for @signinToaddFavourites.
  ///
  /// In en, this message translates to:
  /// **'Sign in to add favorites'**
  String get signinToaddFavourites;

  /// No description provided for @discount.
  ///
  /// In en, this message translates to:
  /// **'Discount'**
  String get discount;

  /// No description provided for @color.
  ///
  /// In en, this message translates to:
  /// **'Color'**
  String get color;

  /// No description provided for @priceRange.
  ///
  /// In en, this message translates to:
  /// **'Price Range'**
  String get priceRange;

  /// No description provided for @weightRange.
  ///
  /// In en, this message translates to:
  /// **'Weight Range'**
  String get weightRange;

  /// No description provided for @options.
  ///
  /// In en, this message translates to:
  /// **'Options'**
  String get options;

  /// No description provided for @filtersApplied.
  ///
  /// In en, this message translates to:
  /// **'Filters Applied'**
  String get filtersApplied;

  /// No description provided for @required.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get required;

  /// No description provided for @paymentDetails.
  ///
  /// In en, this message translates to:
  /// **'Payment Details'**
  String get paymentDetails;

  /// No description provided for @successfulPayment.
  ///
  /// In en, this message translates to:
  /// **'Payment Successful'**
  String get successfulPayment;

  /// No description provided for @unSuccessfulPayment.
  ///
  /// In en, this message translates to:
  /// **'Payment Failed'**
  String get unSuccessfulPayment;

  /// No description provided for @transactionCode.
  ///
  /// In en, this message translates to:
  /// **'Transaction Code'**
  String get transactionCode;

  /// No description provided for @cost.
  ///
  /// In en, this message translates to:
  /// **'Cost'**
  String get cost;

  /// No description provided for @paymentTax.
  ///
  /// In en, this message translates to:
  /// **'Payment Tax'**
  String get paymentTax;

  /// No description provided for @transactionTime.
  ///
  /// In en, this message translates to:
  /// **'Transaction Time'**
  String get transactionTime;

  /// No description provided for @callSupport.
  ///
  /// In en, this message translates to:
  /// **'Call Support'**
  String get callSupport;

  /// No description provided for @messaging.
  ///
  /// In en, this message translates to:
  /// **'Messaging'**
  String get messaging;

  /// No description provided for @invoice.
  ///
  /// In en, this message translates to:
  /// **'Invoice'**
  String get invoice;

  /// No description provided for @notes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get notes;

  /// No description provided for @processing.
  ///
  /// In en, this message translates to:
  /// **'Processing...'**
  String get processing;

  /// No description provided for @error.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get error;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @pending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get pending;

  /// No description provided for @completed.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get completed;

  /// No description provided for @shipping.
  ///
  /// In en, this message translates to:
  /// **'Shipping'**
  String get shipping;

  /// No description provided for @packageImage.
  ///
  /// In en, this message translates to:
  /// **'Package Image'**
  String get packageImage;

  /// No description provided for @shopping.
  ///
  /// In en, this message translates to:
  /// **'Shopping'**
  String get shopping;

  /// No description provided for @tax.
  ///
  /// In en, this message translates to:
  /// **'Tax'**
  String get tax;

  /// No description provided for @default_.
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get default_;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @reason.
  ///
  /// In en, this message translates to:
  /// **'Reason'**
  String get reason;

  /// No description provided for @selectReason.
  ///
  /// In en, this message translates to:
  /// **'Select reason:'**
  String get selectReason;

  /// No description provided for @selectAtLeastOneItem.
  ///
  /// In en, this message translates to:
  /// **'Please select at least one item'**
  String get selectAtLeastOneItem;

  /// No description provided for @pleaseEnterReason.
  ///
  /// In en, this message translates to:
  /// **'Please enter the reason'**
  String get pleaseEnterReason;

  /// No description provided for @verifyPhone.
  ///
  /// In en, this message translates to:
  /// **'Verify Phone'**
  String get verifyPhone;

  /// No description provided for @enterOtpSent.
  ///
  /// In en, this message translates to:
  /// **'Enter the OTP sent to'**
  String get enterOtpSent;

  /// No description provided for @resendOtp.
  ///
  /// In en, this message translates to:
  /// **'Resend OTP'**
  String get resendOtp;

  /// No description provided for @resendOtpIn.
  ///
  /// In en, this message translates to:
  /// **'Resend OTP in'**
  String get resendOtpIn;

  /// No description provided for @seconds.
  ///
  /// In en, this message translates to:
  /// **'seconds'**
  String get seconds;

  /// No description provided for @verify.
  ///
  /// In en, this message translates to:
  /// **'Verify'**
  String get verify;

  /// No description provided for @sendOtp.
  ///
  /// In en, this message translates to:
  /// **'إرسال الرمز'**
  String get sendOtp;

  /// No description provided for @enterCompleteOtp.
  ///
  /// In en, this message translates to:
  /// **'Please enter the complete OTP'**
  String get enterCompleteOtp;

  /// No description provided for @personalInformation.
  ///
  /// In en, this message translates to:
  /// **'Personal Information'**
  String get personalInformation;

  /// No description provided for @personalPhoto.
  ///
  /// In en, this message translates to:
  /// **'Personal Photo *'**
  String get personalPhoto;

  /// No description provided for @gender.
  ///
  /// In en, this message translates to:
  /// **'Gender'**
  String get gender;

  /// No description provided for @courierInformation.
  ///
  /// In en, this message translates to:
  /// **'Courier Information'**
  String get courierInformation;

  /// No description provided for @nationalIdPhoto.
  ///
  /// In en, this message translates to:
  /// **'National ID Photo *'**
  String get nationalIdPhoto;

  /// No description provided for @vehicleLicense.
  ///
  /// In en, this message translates to:
  /// **'Vehicle License Photo *'**
  String get vehicleLicense;

  /// No description provided for @courierLicense.
  ///
  /// In en, this message translates to:
  /// **'Driver License Photo *'**
  String get courierLicense;

  /// No description provided for @vehicleType.
  ///
  /// In en, this message translates to:
  /// **'Vehicle Type'**
  String get vehicleType;

  /// No description provided for @vehiclePlate.
  ///
  /// In en, this message translates to:
  /// **'Vehicle Plate'**
  String get vehiclePlate;

  /// No description provided for @selectPersonalPhoto.
  ///
  /// In en, this message translates to:
  /// **'Please select a personal photo'**
  String get selectPersonalPhoto;

  /// No description provided for @selectNationalIdPhoto.
  ///
  /// In en, this message translates to:
  /// **'Please select a national ID photo'**
  String get selectNationalIdPhoto;

  /// No description provided for @tapToSelectImage.
  ///
  /// In en, this message translates to:
  /// **'Tap to select image'**
  String get tapToSelectImage;

  /// No description provided for @male.
  ///
  /// In en, this message translates to:
  /// **'Male'**
  String get male;

  /// No description provided for @female.
  ///
  /// In en, this message translates to:
  /// **'Female'**
  String get female;

  /// No description provided for @yourAccountWillBeVerified.
  ///
  /// In en, this message translates to:
  /// **'Your courier information will be verified by our team before activation.'**
  String get yourAccountWillBeVerified;

  /// No description provided for @enterPhoneToResetPassword.
  ///
  /// In en, this message translates to:
  /// **'Enter your phone number to reset your password'**
  String get enterPhoneToResetPassword;

  /// No description provided for @resetPassword.
  ///
  /// In en, this message translates to:
  /// **'Reset Password'**
  String get resetPassword;

  /// No description provided for @pleaseLoginWithNewPassword.
  ///
  /// In en, this message translates to:
  /// **'please Login With New Password'**
  String get pleaseLoginWithNewPassword;

  /// No description provided for @packages.
  ///
  /// In en, this message translates to:
  /// **'Packages'**
  String get packages;

  /// No description provided for @statistics.
  ///
  /// In en, this message translates to:
  /// **'Statistics'**
  String get statistics;

  /// No description provided for @deliveryAreas.
  ///
  /// In en, this message translates to:
  /// **'Delivery Areas'**
  String get deliveryAreas;

  /// No description provided for @onFoot.
  ///
  /// In en, this message translates to:
  /// **'onFoot'**
  String get onFoot;

  /// No description provided for @motorcycle.
  ///
  /// In en, this message translates to:
  /// **'motorcycle'**
  String get motorcycle;

  /// No description provided for @bike.
  ///
  /// In en, this message translates to:
  /// **'bike'**
  String get bike;

  /// No description provided for @van.
  ///
  /// In en, this message translates to:
  /// **'van'**
  String get van;

  /// No description provided for @car.
  ///
  /// In en, this message translates to:
  /// **'car'**
  String get car;

  /// No description provided for @tapToViewFullImage.
  ///
  /// In en, this message translates to:
  /// **'Tap To View Full Image'**
  String get tapToViewFullImage;

  /// No description provided for @passwordResetSuccessful.
  ///
  /// In en, this message translates to:
  /// **'Password Reset Successful'**
  String get passwordResetSuccessful;

  /// No description provided for @documents.
  ///
  /// In en, this message translates to:
  /// **'Documents'**
  String get documents;

  /// No description provided for @licensePlate.
  ///
  /// In en, this message translates to:
  /// **'License Plate'**
  String get licensePlate;

  /// No description provided for @vehicleInformation.
  ///
  /// In en, this message translates to:
  /// **'Vehicle Information'**
  String get vehicleInformation;

  /// No description provided for @performanceMetrics.
  ///
  /// In en, this message translates to:
  /// **'Performance Metrics'**
  String get performanceMetrics;

  /// No description provided for @earnings.
  ///
  /// In en, this message translates to:
  /// **'Earnings'**
  String get earnings;

  /// No description provided for @egp.
  ///
  /// In en, this message translates to:
  /// **'EGP'**
  String get egp;

  /// No description provided for @rating.
  ///
  /// In en, this message translates to:
  /// **'Rating'**
  String get rating;

  /// No description provided for @completionRate.
  ///
  /// In en, this message translates to:
  /// **'Completion Rate'**
  String get completionRate;

  /// No description provided for @acceptanceRate.
  ///
  /// In en, this message translates to:
  /// **'Acceptance Rate'**
  String get acceptanceRate;

  /// No description provided for @avgDeliveryTime.
  ///
  /// In en, this message translates to:
  /// **'Avg Delivery Time'**
  String get avgDeliveryTime;

  /// No description provided for @min.
  ///
  /// In en, this message translates to:
  /// **'min'**
  String get min;

  /// No description provided for @hour.
  ///
  /// In en, this message translates to:
  /// **'hour'**
  String get hour;

  /// No description provided for @totalReviews.
  ///
  /// In en, this message translates to:
  /// **'Total Reviews'**
  String get totalReviews;

  /// No description provided for @cancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get cancelled;

  /// No description provided for @earn.
  ///
  /// In en, this message translates to:
  /// **'Earn'**
  String get earn;

  /// No description provided for @commissionRate.
  ///
  /// In en, this message translates to:
  /// **'Commission Rate'**
  String get commissionRate;

  /// No description provided for @deliveries.
  ///
  /// In en, this message translates to:
  /// **'Deliveries'**
  String get deliveries;

  /// No description provided for @badgeProgress.
  ///
  /// In en, this message translates to:
  /// **'Badge Progress'**
  String get badgeProgress;

  /// No description provided for @status.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get status;

  /// No description provided for @pendingApproval.
  ///
  /// In en, this message translates to:
  /// **'Pending Approval'**
  String get pendingApproval;

  /// No description provided for @phoneVerified.
  ///
  /// In en, this message translates to:
  /// **'Phone Verified'**
  String get phoneVerified;

  /// No description provided for @yes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get yes;

  /// No description provided for @no.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get no;

  /// No description provided for @accountInformation.
  ///
  /// In en, this message translates to:
  /// **'Account Information'**
  String get accountInformation;

  /// No description provided for @approved.
  ///
  /// In en, this message translates to:
  /// **'Approved'**
  String get approved;

  /// No description provided for @orders.
  ///
  /// In en, this message translates to:
  /// **'Orders'**
  String get orders;

  /// No description provided for @availableOrders.
  ///
  /// In en, this message translates to:
  /// **'Available Orders'**
  String get availableOrders;

  /// No description provided for @noAvailableOrders.
  ///
  /// In en, this message translates to:
  /// **'No Available Orders'**
  String get noAvailableOrders;

  /// No description provided for @checkBackLater.
  ///
  /// In en, this message translates to:
  /// **'Check back later for new delivery opportunities'**
  String get checkBackLater;

  /// No description provided for @refresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refresh;

  /// No description provided for @ordersCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No orders} =1{1 order} other{{count} orders}}'**
  String ordersCount(int count);

  /// No description provided for @orderDetails.
  ///
  /// In en, this message translates to:
  /// **'Order Details'**
  String get orderDetails;

  /// No description provided for @productDetails.
  ///
  /// In en, this message translates to:
  /// **'Product Details'**
  String get productDetails;

  /// No description provided for @customerInformation.
  ///
  /// In en, this message translates to:
  /// **'Customer Information'**
  String get customerInformation;

  /// No description provided for @deliveryRoute.
  ///
  /// In en, this message translates to:
  /// **'Delivery Route'**
  String get deliveryRoute;

  /// No description provided for @orderInformation.
  ///
  /// In en, this message translates to:
  /// **'Order Information'**
  String get orderInformation;

  /// No description provided for @invalidQrCode.
  ///
  /// In en, this message translates to:
  /// **'Invalid QR Code: Not a delivery confirmation code'**
  String get invalidQrCode;

  /// No description provided for @invalidQrCodeFormat.
  ///
  /// In en, this message translates to:
  /// **'Invalid QR Code format'**
  String get invalidQrCodeFormat;

  /// No description provided for @scanQrCode.
  ///
  /// In en, this message translates to:
  /// **'Scan QR Code'**
  String get scanQrCode;

  /// No description provided for @deliveryConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Delivery confirmed successfully!'**
  String get deliveryConfirmed;

  /// No description provided for @scanDeliveryQrCode.
  ///
  /// In en, this message translates to:
  /// **'Scan the delivery confirmation QR code from the courier'**
  String get scanDeliveryQrCode;

  /// No description provided for @alignQrCode.
  ///
  /// In en, this message translates to:
  /// **'Align QR code within the frame'**
  String get alignQrCode;

  /// No description provided for @pickup.
  ///
  /// In en, this message translates to:
  /// **'Pickup'**
  String get pickup;

  /// No description provided for @delivery.
  ///
  /// In en, this message translates to:
  /// **'Delivery'**
  String get delivery;

  /// No description provided for @pickupLocation.
  ///
  /// In en, this message translates to:
  /// **'Pickup Location'**
  String get pickupLocation;

  /// No description provided for @deliveryLocation.
  ///
  /// In en, this message translates to:
  /// **'Delivery Location'**
  String get deliveryLocation;

  /// No description provided for @budget.
  ///
  /// In en, this message translates to:
  /// **'Budget'**
  String get budget;

  /// No description provided for @customerBudget.
  ///
  /// In en, this message translates to:
  /// **'Customer Budget'**
  String get customerBudget;

  /// No description provided for @offerSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Offer Submitted'**
  String get offerSubmitted;

  /// No description provided for @offerSubmittedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Offer submitted successfully!'**
  String get offerSubmittedSuccessfully;

  /// No description provided for @offerAlreadySubmitted.
  ///
  /// In en, this message translates to:
  /// **'Offer Already Submitted'**
  String get offerAlreadySubmitted;

  /// No description provided for @waitingForCustomerResponse.
  ///
  /// In en, this message translates to:
  /// **'Waiting for customer to review your offer'**
  String get waitingForCustomerResponse;

  /// No description provided for @submitYourOffer.
  ///
  /// In en, this message translates to:
  /// **'Submit Your Offer'**
  String get submitYourOffer;

  /// No description provided for @submitOffer.
  ///
  /// In en, this message translates to:
  /// **'Submit Offer'**
  String get submitOffer;

  /// No description provided for @submitting.
  ///
  /// In en, this message translates to:
  /// **'Submitting...'**
  String get submitting;

  /// No description provided for @allowedFeeRange.
  ///
  /// In en, this message translates to:
  /// **'Allowed Fee Range'**
  String get allowedFeeRange;

  /// No description provided for @yourDeliveryFee.
  ///
  /// In en, this message translates to:
  /// **'Your Delivery Fee (EGP)'**
  String get yourDeliveryFee;

  /// No description provided for @pleaseEnterDeliveryFee.
  ///
  /// In en, this message translates to:
  /// **'Please enter your delivery fee'**
  String get pleaseEnterDeliveryFee;

  /// No description provided for @pleaseEnterValidNumber.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid number'**
  String get pleaseEnterValidNumber;

  /// No description provided for @feeMustBeBetween.
  ///
  /// In en, this message translates to:
  /// **'Fee must be between {min} and {max} EGP'**
  String feeMustBeBetween(String min, String max);

  /// No description provided for @created.
  ///
  /// In en, this message translates to:
  /// **'Created'**
  String get created;

  /// No description provided for @inProgress.
  ///
  /// In en, this message translates to:
  /// **'In Progress'**
  String get inProgress;

  /// No description provided for @delivered.
  ///
  /// In en, this message translates to:
  /// **'Delivered'**
  String get delivered;

  /// No description provided for @justNow.
  ///
  /// In en, this message translates to:
  /// **'Just now'**
  String get justNow;

  /// No description provided for @minutesAgo.
  ///
  /// In en, this message translates to:
  /// **'{minutes}m ago'**
  String minutesAgo(int minutes);

  /// No description provided for @hoursAgo.
  ///
  /// In en, this message translates to:
  /// **'{hours}h ago'**
  String hoursAgo(int hours);

  /// No description provided for @daysAgo.
  ///
  /// In en, this message translates to:
  /// **'{days}d ago'**
  String daysAgo(int days);

  /// No description provided for @activeOrder.
  ///
  /// In en, this message translates to:
  /// **'Active Order'**
  String get activeOrder;

  /// No description provided for @noActiveOrder.
  ///
  /// In en, this message translates to:
  /// **'No Active Order'**
  String get noActiveOrder;

  /// No description provided for @noActiveDeliveries.
  ///
  /// In en, this message translates to:
  /// **'You don\'t have any active deliveries'**
  String get noActiveDeliveries;

  /// No description provided for @deliveryInProgress.
  ///
  /// In en, this message translates to:
  /// **'Delivery In Progress'**
  String get deliveryInProgress;

  /// No description provided for @completeDelivery.
  ///
  /// In en, this message translates to:
  /// **'Complete Delivery'**
  String get completeDelivery;

  /// No description provided for @generateQrCode.
  ///
  /// In en, this message translates to:
  /// **'Generate QR Code'**
  String get generateQrCode;

  /// No description provided for @actualProductPrice.
  ///
  /// In en, this message translates to:
  /// **'Actual Product Price (EGP)'**
  String get actualProductPrice;

  /// No description provided for @pleaseEnterActualPrice.
  ///
  /// In en, this message translates to:
  /// **'Please enter the actual product price'**
  String get pleaseEnterActualPrice;

  /// No description provided for @pleaseEnterValidPrice.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid price'**
  String get pleaseEnterValidPrice;

  /// No description provided for @enterActualPriceMessage.
  ///
  /// In en, this message translates to:
  /// **'Enter the actual product price to generate QR code for customer confirmation'**
  String get enterActualPriceMessage;

  /// No description provided for @deliveryQrCode.
  ///
  /// In en, this message translates to:
  /// **'Delivery QR Code'**
  String get deliveryQrCode;

  /// No description provided for @deliveryReady.
  ///
  /// In en, this message translates to:
  /// **'Delivery Ready!'**
  String get deliveryReady;

  /// No description provided for @showQrCodeMessage.
  ///
  /// In en, this message translates to:
  /// **'Show this QR code to the customer for confirmation'**
  String get showQrCodeMessage;

  /// No description provided for @instructions.
  ///
  /// In en, this message translates to:
  /// **'Instructions'**
  String get instructions;

  /// No description provided for @instructionStep1.
  ///
  /// In en, this message translates to:
  /// **'1. Ask the customer to open their app'**
  String get instructionStep1;

  /// No description provided for @instructionStep2.
  ///
  /// In en, this message translates to:
  /// **'2. They will scan this QR code'**
  String get instructionStep2;

  /// No description provided for @instructionStep3.
  ///
  /// In en, this message translates to:
  /// **'3. Wait for confirmation'**
  String get instructionStep3;

  /// No description provided for @instructionStep4.
  ///
  /// In en, this message translates to:
  /// **'4. Delivery complete!'**
  String get instructionStep4;

  /// No description provided for @timeline.
  ///
  /// In en, this message translates to:
  /// **'Timeline'**
  String get timeline;

  /// No description provided for @orderCreated.
  ///
  /// In en, this message translates to:
  /// **'Order Created'**
  String get orderCreated;

  /// No description provided for @offerAccepted.
  ///
  /// In en, this message translates to:
  /// **'Offer Accepted'**
  String get offerAccepted;

  /// No description provided for @customer.
  ///
  /// In en, this message translates to:
  /// **'Customer'**
  String get customer;

  /// No description provided for @yourFee.
  ///
  /// In en, this message translates to:
  /// **'Your Fee'**
  String get yourFee;

  /// No description provided for @totalFee.
  ///
  /// In en, this message translates to:
  /// **'Total Fee'**
  String get totalFee;

  /// No description provided for @otherReason.
  ///
  /// In en, this message translates to:
  /// **'Other Reason'**
  String get otherReason;

  /// No description provided for @productUnAvailable.
  ///
  /// In en, this message translates to:
  /// **'Product Unavailable'**
  String get productUnAvailable;

  /// No description provided for @budgetNotEnough.
  ///
  /// In en, this message translates to:
  /// **'Budget Is Not Enough'**
  String get budgetNotEnough;

  /// No description provided for @askCustomer.
  ///
  /// In en, this message translates to:
  /// **'Tell Customer'**
  String get askCustomer;

  /// No description provided for @history.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get history;

  /// No description provided for @orderCancelled.
  ///
  /// In en, this message translates to:
  /// **'Order Cancelled'**
  String get orderCancelled;

  /// No description provided for @actualPriceMustBeHigher.
  ///
  /// In en, this message translates to:
  /// **'Actual Price Must Be Higher'**
  String get actualPriceMustBeHigher;

  /// No description provided for @reportActualPrice.
  ///
  /// In en, this message translates to:
  /// **'Report Actual Price'**
  String get reportActualPrice;

  /// No description provided for @tooShort.
  ///
  /// In en, this message translates to:
  /// **'too short'**
  String get tooShort;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @actualPriceIsHigher.
  ///
  /// In en, this message translates to:
  /// **'Actual Price Is Higher'**
  String get actualPriceIsHigher;

  /// No description provided for @wallet.
  ///
  /// In en, this message translates to:
  /// **'Wallet'**
  String get wallet;

  /// No description provided for @viewProposals.
  ///
  /// In en, this message translates to:
  /// **'View Proposals'**
  String get viewProposals;

  /// No description provided for @useThisAddress.
  ///
  /// In en, this message translates to:
  /// **'Use this address'**
  String get useThisAddress;

  /// No description provided for @selectArea.
  ///
  /// In en, this message translates to:
  /// **'Select area'**
  String get selectArea;

  /// No description provided for @locationRequired.
  ///
  /// In en, this message translates to:
  /// **'Location is required'**
  String get locationRequired;

  /// No description provided for @openSettings.
  ///
  /// In en, this message translates to:
  /// **'Open settings'**
  String get openSettings;

  /// No description provided for @setAsDefault.
  ///
  /// In en, this message translates to:
  /// **'Set as default'**
  String get setAsDefault;

  /// No description provided for @pleaseSelectArea.
  ///
  /// In en, this message translates to:
  /// **'Please select an area'**
  String get pleaseSelectArea;

  /// No description provided for @noAreasAvailable.
  ///
  /// In en, this message translates to:
  /// **'No areas available'**
  String get noAreasAvailable;

  /// No description provided for @addressNameHint.
  ///
  /// In en, this message translates to:
  /// **'Address name'**
  String get addressNameHint;

  /// No description provided for @addressNameOptional.
  ///
  /// In en, this message translates to:
  /// **'Address name'**
  String get addressNameOptional;

  /// No description provided for @distanceTooClose.
  ///
  /// In en, this message translates to:
  /// **'Pickup and delivery locations are too close. Please choose different locations'**
  String get distanceTooClose;

  /// No description provided for @pleaseSelectLocation.
  ///
  /// In en, this message translates to:
  /// **'Please select a location'**
  String get pleaseSelectLocation;

  /// No description provided for @oneTimeAddress.
  ///
  /// In en, this message translates to:
  /// **'Enter Adress (Don\'t Save)'**
  String get oneTimeAddress;

  /// No description provided for @productImageOptional.
  ///
  /// In en, this message translates to:
  /// **'Product Image (Optional)'**
  String get productImageOptional;

  /// No description provided for @newOrder.
  ///
  /// In en, this message translates to:
  /// **'New Order'**
  String get newOrder;

  /// No description provided for @acceptProposalConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to accept this proposal?'**
  String get acceptProposalConfirmation;

  /// No description provided for @acceptProposal.
  ///
  /// In en, this message translates to:
  /// **'Accept Proposal'**
  String get acceptProposal;

  /// No description provided for @rejectProposalConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to reject this proposal?'**
  String get rejectProposalConfirmation;

  /// No description provided for @rejectProposal.
  ///
  /// In en, this message translates to:
  /// **'Reject Proposal'**
  String get rejectProposal;

  /// No description provided for @proposals.
  ///
  /// In en, this message translates to:
  /// **'Proposals'**
  String get proposals;

  /// No description provided for @reject.
  ///
  /// In en, this message translates to:
  /// **'Reject'**
  String get reject;

  /// No description provided for @accept.
  ///
  /// In en, this message translates to:
  /// **'Accept'**
  String get accept;

  /// No description provided for @rejected.
  ///
  /// In en, this message translates to:
  /// **'Rejected'**
  String get rejected;

  /// No description provided for @accepted.
  ///
  /// In en, this message translates to:
  /// **'Accepted'**
  String get accepted;

  /// No description provided for @deliveryFee.
  ///
  /// In en, this message translates to:
  /// **'Delivery Fee'**
  String get deliveryFee;

  /// No description provided for @couriersWillSendProposalsSoon.
  ///
  /// In en, this message translates to:
  /// **'Couriers will send proposals soon'**
  String get couriersWillSendProposalsSoon;

  /// No description provided for @noProposalsYet.
  ///
  /// In en, this message translates to:
  /// **'No proposals yet'**
  String get noProposalsYet;

  /// No description provided for @orderCancelledUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Order Cancelled - your product is Unavailable'**
  String get orderCancelledUnavailable;

  /// No description provided for @view.
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get view;

  /// No description provided for @tapToView.
  ///
  /// In en, this message translates to:
  /// **'Tap To View'**
  String get tapToView;

  /// No description provided for @newProposalReceived.
  ///
  /// In en, this message translates to:
  /// **'New Proposal Received'**
  String get newProposalReceived;

  /// No description provided for @cancelOrderWarning.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to cancel this order? This action cannot be undone.'**
  String get cancelOrderWarning;

  /// No description provided for @reviewsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} Reviews'**
  String reviewsCount(int count);

  /// No description provided for @averageRating.
  ///
  /// In en, this message translates to:
  /// **'Average Rating'**
  String get averageRating;

  /// No description provided for @rateTheCourier.
  ///
  /// In en, this message translates to:
  /// **'Rate the Courier'**
  String get rateTheCourier;

  /// No description provided for @howWasYourExperience.
  ///
  /// In en, this message translates to:
  /// **'How was your experience with this courier?'**
  String get howWasYourExperience;

  /// No description provided for @leaveAComment.
  ///
  /// In en, this message translates to:
  /// **'Leave a comment (optional)'**
  String get leaveAComment;

  /// No description provided for @submitReview.
  ///
  /// In en, this message translates to:
  /// **'Submit Review'**
  String get submitReview;

  /// No description provided for @pleaseSelectRating.
  ///
  /// In en, this message translates to:
  /// **'Please select a rating'**
  String get pleaseSelectRating;

  /// No description provided for @ratingPoor.
  ///
  /// In en, this message translates to:
  /// **'Poor'**
  String get ratingPoor;

  /// No description provided for @ratingFair.
  ///
  /// In en, this message translates to:
  /// **'Fair'**
  String get ratingFair;

  /// No description provided for @ratingGood.
  ///
  /// In en, this message translates to:
  /// **'Good'**
  String get ratingGood;

  /// No description provided for @ratingVeryGood.
  ///
  /// In en, this message translates to:
  /// **'Very Good'**
  String get ratingVeryGood;

  /// No description provided for @topUpWallet.
  ///
  /// In en, this message translates to:
  /// **'Top Up Wallet'**
  String get topUpWallet;

  /// No description provided for @selectAmount.
  ///
  /// In en, this message translates to:
  /// **'Select Amount'**
  String get selectAmount;

  /// No description provided for @orEnterCustomAmount.
  ///
  /// In en, this message translates to:
  /// **'Or Enter Custom Amount'**
  String get orEnterCustomAmount;

  /// No description provided for @minimumTopUp.
  ///
  /// In en, this message translates to:
  /// **'Min: 10 EGP | Max: 5000 EGP'**
  String get minimumTopUp;

  /// No description provided for @selectPaymentMethod.
  ///
  /// In en, this message translates to:
  /// **'Select Payment Method'**
  String get selectPaymentMethod;

  /// No description provided for @creditDebitCard.
  ///
  /// In en, this message translates to:
  /// **'Credit/Debit Card'**
  String get creditDebitCard;

  /// No description provided for @onlinePayment.
  ///
  /// In en, this message translates to:
  /// **'Online Payment'**
  String get onlinePayment;

  /// No description provided for @mobileWalletInstaPay.
  ///
  /// In en, this message translates to:
  /// **'Mobile Wallet / InstaPay'**
  String get mobileWalletInstaPay;

  /// No description provided for @transferToOurNumbers.
  ///
  /// In en, this message translates to:
  /// **'Transfer to our numbers'**
  String get transferToOurNumbers;

  /// No description provided for @manualTransfer.
  ///
  /// In en, this message translates to:
  /// **'Manual Transfer'**
  String get manualTransfer;

  /// No description provided for @transferAmount.
  ///
  /// In en, this message translates to:
  /// **'Transfer the amount to one of these accounts'**
  String get transferAmount;

  /// No description provided for @keepReceipt.
  ///
  /// In en, this message translates to:
  /// **'Keep your transfer receipt'**
  String get keepReceipt;

  /// No description provided for @contactSupport.
  ///
  /// In en, this message translates to:
  /// **'Contact support to confirm transfer'**
  String get contactSupport;

  /// No description provided for @balanceWillBeAdded.
  ///
  /// In en, this message translates to:
  /// **'Balance will be added to your wallet after support confirms the transfer (usually within 1-2 business hours)'**
  String get balanceWillBeAdded;

  /// No description provided for @vodafoneCash.
  ///
  /// In en, this message translates to:
  /// **'Vodafone Cash'**
  String get vodafoneCash;

  /// No description provided for @instaPay.
  ///
  /// In en, this message translates to:
  /// **'InstaPay'**
  String get instaPay;

  /// No description provided for @copiedToClipboard.
  ///
  /// In en, this message translates to:
  /// **'Copied to clipboard'**
  String get copiedToClipboard;

  /// No description provided for @copy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get copy;

  /// No description provided for @searchingFailed.
  ///
  /// In en, this message translates to:
  /// **'Searching Failed'**
  String get searchingFailed;

  /// No description provided for @expired.
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get expired;

  /// No description provided for @success.
  ///
  /// In en, this message translates to:
  /// **'Success!'**
  String get success;

  /// No description provided for @walletToppedUp.
  ///
  /// In en, this message translates to:
  /// **'Your wallet has been topped up successfully'**
  String get walletToppedUp;

  /// No description provided for @amountAdded.
  ///
  /// In en, this message translates to:
  /// **'Amount Added'**
  String get amountAdded;

  /// No description provided for @transactionId.
  ///
  /// In en, this message translates to:
  /// **'Transaction ID'**
  String get transactionId;

  /// No description provided for @pendingCommissionsDeducted.
  ///
  /// In en, this message translates to:
  /// **'Any pending penalties were automatically deducted'**
  String get pendingCommissionsDeducted;

  /// No description provided for @backToWallet.
  ///
  /// In en, this message translates to:
  /// **'Back to Wallet'**
  String get backToWallet;

  /// No description provided for @cancelPayment.
  ///
  /// In en, this message translates to:
  /// **'Cancel Payment?'**
  String get cancelPayment;

  /// No description provided for @cancelPaymentConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to cancel the payment?'**
  String get cancelPaymentConfirm;

  /// No description provided for @transactionHistory.
  ///
  /// In en, this message translates to:
  /// **'Transaction History'**
  String get transactionHistory;

  /// No description provided for @topup.
  ///
  /// In en, this message translates to:
  /// **'Top Up'**
  String get topup;

  /// No description provided for @amount.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get amount;

  /// No description provided for @pleaseEnterAmount.
  ///
  /// In en, this message translates to:
  /// **'Please Enter Amount'**
  String get pleaseEnterAmount;

  /// No description provided for @minimumTopUpIs.
  ///
  /// In en, this message translates to:
  /// **'Minimum top-up is 10 EGP'**
  String get minimumTopUpIs;

  /// No description provided for @maximumTopUpIs.
  ///
  /// In en, this message translates to:
  /// **'Maximum top-up is 5000 EGP'**
  String get maximumTopUpIs;

  /// No description provided for @paymentFailed.
  ///
  /// In en, this message translates to:
  /// **'Payment failed'**
  String get paymentFailed;

  /// No description provided for @pendingCommissionsWillBeDeducted.
  ///
  /// In en, this message translates to:
  /// **'Any pending penalties will be automatically deducted upon top-up'**
  String get pendingCommissionsWillBeDeducted;

  /// No description provided for @couponCode.
  ///
  /// In en, this message translates to:
  /// **'Coupon Code'**
  String get couponCode;

  /// No description provided for @applyCoupon.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get applyCoupon;

  /// No description provided for @couponApplied.
  ///
  /// In en, this message translates to:
  /// **'Coupon \"{title}\" applied!'**
  String couponApplied(String title);

  /// No description provided for @couponRedeemed.
  ///
  /// In en, this message translates to:
  /// **'Coupon Applied!'**
  String get couponRedeemed;

  /// No description provided for @offYourOrder.
  ///
  /// In en, this message translates to:
  /// **'off your order'**
  String get offYourOrder;

  /// No description provided for @couponRedeemFailed.
  ///
  /// In en, this message translates to:
  /// **'Coupon Apply failed: {message}'**
  String couponRedeemFailed(String message);

  /// No description provided for @removeCoupon.
  ///
  /// In en, this message translates to:
  /// **'Remove coupon'**
  String get removeCoupon;

  /// No description provided for @walletCredit.
  ///
  /// In en, this message translates to:
  /// **'+{amount} EGP wallet credit'**
  String walletCredit(String amount);

  /// No description provided for @walletPoints.
  ///
  /// In en, this message translates to:
  /// **'+{points} points'**
  String walletPoints(int points);

  /// No description provided for @walletBalance.
  ///
  /// In en, this message translates to:
  /// **'Wallet Balance'**
  String get walletBalance;

  /// No description provided for @active.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get active;

  /// No description provided for @frozen.
  ///
  /// In en, this message translates to:
  /// **'Frozen'**
  String get frozen;

  /// No description provided for @availableBalance.
  ///
  /// In en, this message translates to:
  /// **'Available Balance'**
  String get availableBalance;

  /// No description provided for @estimatedShippingFee.
  ///
  /// In en, this message translates to:
  /// **'Estimated Shipping Fee'**
  String get estimatedShippingFee;

  /// No description provided for @km.
  ///
  /// In en, this message translates to:
  /// **'km'**
  String get km;

  /// No description provided for @m.
  ///
  /// In en, this message translates to:
  /// **'M'**
  String get m;

  /// No description provided for @iAgreeTo.
  ///
  /// In en, this message translates to:
  /// **'By signing in or signing up, you agree to'**
  String get iAgreeTo;

  /// No description provided for @okay.
  ///
  /// In en, this message translates to:
  /// **'Ok'**
  String get okay;

  /// No description provided for @pickupAddressOutOfArea.
  ///
  /// In en, this message translates to:
  /// **'pickup Address Out Of Area'**
  String get pickupAddressOutOfArea;

  /// No description provided for @deliveryAddressOutOfArea.
  ///
  /// In en, this message translates to:
  /// **'delivery Address Out Of Area'**
  String get deliveryAddressOutOfArea;

  /// No description provided for @addressOutsideArea.
  ///
  /// In en, this message translates to:
  /// **'Selected location is outside the chosen area. Please pick a location within the area.'**
  String get addressOutsideArea;

  /// No description provided for @insufficientBalance.
  ///
  /// In en, this message translates to:
  /// **'Insufficient Balance'**
  String get insufficientBalance;

  /// No description provided for @insufficientBalanceShoppingDesc.
  ///
  /// In en, this message translates to:
  /// **'Your wallet balance does not cover the shipping fee and budget'**
  String get insufficientBalanceShoppingDesc;

  /// No description provided for @insufficientBalanceShippingDesc.
  ///
  /// In en, this message translates to:
  /// **'Your wallet balance does not cover the shipping fee'**
  String get insufficientBalanceShippingDesc;

  /// No description provided for @currentBalance.
  ///
  /// In en, this message translates to:
  /// **'Current Balance'**
  String get currentBalance;

  /// No description provided for @requiredAmount.
  ///
  /// In en, this message translates to:
  /// **'Required Amount'**
  String get requiredAmount;

  /// No description provided for @shortfall.
  ///
  /// In en, this message translates to:
  /// **'Shortfall'**
  String get shortfall;

  /// No description provided for @topUpNow.
  ///
  /// In en, this message translates to:
  /// **'Top Up Wallet Now'**
  String get topUpNow;

  /// No description provided for @notNow.
  ///
  /// In en, this message translates to:
  /// **'Not Now'**
  String get notNow;

  /// No description provided for @addressMayBeOutsideArea.
  ///
  /// In en, this message translates to:
  /// **'Address may be outside the selected area'**
  String get addressMayBeOutsideArea;

  /// No description provided for @pleaseEnterProductDescription.
  ///
  /// In en, this message translates to:
  /// **'Please enter product description'**
  String get pleaseEnterProductDescription;

  /// No description provided for @pleaseEnterBudget.
  ///
  /// In en, this message translates to:
  /// **'Please enter budget'**
  String get pleaseEnterBudget;

  /// No description provided for @walletBalanceHintShipping.
  ///
  /// In en, this message translates to:
  /// **'Make sure you have enough wallet balance to cover the shipping fee'**
  String get walletBalanceHintShipping;

  /// No description provided for @walletBalanceHintShopping.
  ///
  /// In en, this message translates to:
  /// **'Make sure you have enough wallet balance if you want to use it to pay for your order'**
  String get walletBalanceHintShopping;

  /// No description provided for @walletBalanceHintOverBudget.
  ///
  /// In en, this message translates to:
  /// **'If the budget is higher than'**
  String get walletBalanceHintOverBudget;

  /// No description provided for @walletBalanceHintOverBudget2.
  ///
  /// In en, this message translates to:
  /// **'payment will be made via wallet only'**
  String get walletBalanceHintOverBudget2;

  /// No description provided for @cod.
  ///
  /// In en, this message translates to:
  /// **'COD'**
  String get cod;

  /// No description provided for @codN.
  ///
  /// In en, this message translates to:
  /// **'COD'**
  String get codN;

  /// No description provided for @far.
  ///
  /// In en, this message translates to:
  /// **'Away'**
  String get far;

  /// No description provided for @outForDelivery.
  ///
  /// In en, this message translates to:
  /// **'Out For Delivery'**
  String get outForDelivery;

  /// No description provided for @confirmDelivery.
  ///
  /// In en, this message translates to:
  /// **'Confirm Delivery'**
  String get confirmDelivery;

  /// No description provided for @confirmDeliveryMessage.
  ///
  /// In en, this message translates to:
  /// **'Are you sure the order has been delivered to the customer?'**
  String get confirmDeliveryMessage;

  /// No description provided for @ratingExcellent.
  ///
  /// In en, this message translates to:
  /// **'Excellent'**
  String get ratingExcellent;

  /// No description provided for @referral.
  ///
  /// In en, this message translates to:
  /// **'Referral'**
  String get referral;

  /// No description provided for @referrals.
  ///
  /// In en, this message translates to:
  /// **'Referrals'**
  String get referrals;

  /// No description provided for @whatsapp.
  ///
  /// In en, this message translates to:
  /// **'Whatsapp'**
  String get whatsapp;

  /// No description provided for @knowUsMore.
  ///
  /// In en, this message translates to:
  /// **'Know Us More'**
  String get knowUsMore;

  /// No description provided for @preparingOrder.
  ///
  /// In en, this message translates to:
  /// **'Your order is being prepared'**
  String get preparingOrder;

  /// No description provided for @findingCourier.
  ///
  /// In en, this message translates to:
  /// **'We\'re finding you the best courier…'**
  String get findingCourier;

  /// No description provided for @offDeliveryFee.
  ///
  /// In en, this message translates to:
  /// **'off delivery fee'**
  String get offDeliveryFee;

  /// No description provided for @nearMe.
  ///
  /// In en, this message translates to:
  /// **'Near Me'**
  String get nearMe;
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['ar', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {


  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar': return AppLocalizationsAr();
    case 'en': return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.'
  );
}

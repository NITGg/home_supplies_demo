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
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

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
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en'),
  ];

  /// No description provided for @onboardTitle1.
  ///
  /// In en, this message translates to:
  /// **'Discover Everything You Need'**
  String get onboardTitle1;

  /// No description provided for @onboardTitle2.
  ///
  /// In en, this message translates to:
  /// **'Shop Easily and Safely'**
  String get onboardTitle2;

  /// No description provided for @onboardTitle3.
  ///
  /// In en, this message translates to:
  /// **'Fast Delivery, Guaranteed Quality'**
  String get onboardTitle3;

  /// No description provided for @onboardSubtitle1.
  ///
  /// In en, this message translates to:
  /// **'All your construction supplies in one app'**
  String get onboardSubtitle1;

  /// No description provided for @onboardSubtitle2.
  ///
  /// In en, this message translates to:
  /// **'Choose and pay securely'**
  String get onboardSubtitle2;

  /// No description provided for @onboardSubtitle3.
  ///
  /// In en, this message translates to:
  /// **'Faster delivery… better materials'**
  String get onboardSubtitle3;

  /// No description provided for @onboardBody1.
  ///
  /// In en, this message translates to:
  /// **'From building materials to paints and sanitary tools — everything you need is right here.'**
  String get onboardBody1;

  /// No description provided for @onboardBody2.
  ///
  /// In en, this message translates to:
  /// **'Flexible payment options including online or cash on delivery.'**
  String get onboardBody2;

  /// No description provided for @onboardBody3.
  ///
  /// In en, this message translates to:
  /// **'Certified products delivered quickly and safely to your site.'**
  String get onboardBody3;

  /// No description provided for @next.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get next;

  /// No description provided for @prev.
  ///
  /// In en, this message translates to:
  /// **'Prev'**
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

  /// No description provided for @shop_now.
  ///
  /// In en, this message translates to:
  /// **'Shop Now'**
  String get shop_now;

  /// No description provided for @home.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// No description provided for @brands.
  ///
  /// In en, this message translates to:
  /// **'Brands'**
  String get brands;

  /// No description provided for @categories.
  ///
  /// In en, this message translates to:
  /// **'Categories'**
  String get categories;

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
  /// **'Tawreedat is your choice'**
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

  /// No description provided for @favourites.
  ///
  /// In en, this message translates to:
  /// **'Favourites'**
  String get favourites;

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
  /// **'Sign in'**
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
  /// **'Or SignIn With'**
  String get orSignInwith;

  /// No description provided for @orRegisterwith.
  ///
  /// In en, this message translates to:
  /// **'Or Register With'**
  String get orRegisterwith;

  /// No description provided for @enterAsGuest.
  ///
  /// In en, this message translates to:
  /// **'Enter As Guest'**
  String get enterAsGuest;

  /// No description provided for @dontHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account!'**
  String get dontHaveAccount;

  /// No description provided for @haveAccount.
  ///
  /// In en, this message translates to:
  /// **'have an account!'**
  String get haveAccount;

  /// No description provided for @points.
  ///
  /// In en, this message translates to:
  /// **'Points'**
  String get points;

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// No description provided for @searchFor.
  ///
  /// In en, this message translates to:
  /// **'Search For....'**
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

  /// No description provided for @myProducts.
  ///
  /// In en, this message translates to:
  /// **'My Products'**
  String get myProducts;

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
  /// **'All marked as read'**
  String get markAllAsRead;

  /// No description provided for @clearAll.
  ///
  /// In en, this message translates to:
  /// **'Clear All'**
  String get clearAll;

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

  /// No description provided for @discounts.
  ///
  /// In en, this message translates to:
  /// **'Discounts'**
  String get discounts;

  /// No description provided for @bestSeller.
  ///
  /// In en, this message translates to:
  /// **'Best Seller'**
  String get bestSeller;

  /// No description provided for @featured.
  ///
  /// In en, this message translates to:
  /// **'Featured'**
  String get featured;

  /// No description provided for @sellingUnit.
  ///
  /// In en, this message translates to:
  /// **'Selling Unit'**
  String get sellingUnit;

  /// No description provided for @subtotal.
  ///
  /// In en, this message translates to:
  /// **'Subtotal:'**
  String get subtotal;

  /// No description provided for @sum.
  ///
  /// In en, this message translates to:
  /// **'Sum'**
  String get sum;

  /// No description provided for @products.
  ///
  /// In en, this message translates to:
  /// **'Products'**
  String get products;

  /// No description provided for @product.
  ///
  /// In en, this message translates to:
  /// **'Product'**
  String get product;

  /// No description provided for @quantity.
  ///
  /// In en, this message translates to:
  /// **'Quantity'**
  String get quantity;

  /// No description provided for @addToCart.
  ///
  /// In en, this message translates to:
  /// **'Add to cart'**
  String get addToCart;

  /// No description provided for @cart.
  ///
  /// In en, this message translates to:
  /// **'Cart'**
  String get cart;

  /// No description provided for @price.
  ///
  /// In en, this message translates to:
  /// **'Price:'**
  String get price;

  /// No description provided for @info.
  ///
  /// In en, this message translates to:
  /// **'info'**
  String get info;

  /// No description provided for @productDescription.
  ///
  /// In en, this message translates to:
  /// **'Product Description'**
  String get productDescription;

  /// No description provided for @deleteAll.
  ///
  /// In en, this message translates to:
  /// **'Delete All'**
  String get deleteAll;

  /// No description provided for @completePurchase.
  ///
  /// In en, this message translates to:
  /// **'Complete Purchase'**
  String get completePurchase;

  /// No description provided for @continueShopping.
  ///
  /// In en, this message translates to:
  /// **'Continue Shopping'**
  String get continueShopping;

  /// No description provided for @payment.
  ///
  /// In en, this message translates to:
  /// **'Payment'**
  String get payment;

  /// No description provided for @payNow.
  ///
  /// In en, this message translates to:
  /// **'pay Now'**
  String get payNow;

  /// No description provided for @cancelOrder.
  ///
  /// In en, this message translates to:
  /// **'Cancel Order'**
  String get cancelOrder;

  /// No description provided for @requestRefund.
  ///
  /// In en, this message translates to:
  /// **'Request Refund'**
  String get requestRefund;

  /// No description provided for @requestRefundAll.
  ///
  /// In en, this message translates to:
  /// **'refund whole order'**
  String get requestRefundAll;

  /// No description provided for @requestRefundPart.
  ///
  /// In en, this message translates to:
  /// **'refund product'**
  String get requestRefundPart;

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
  /// **'Details and address'**
  String get detailsAndAddress;

  /// No description provided for @name.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get name;

  /// No description provided for @governate.
  ///
  /// In en, this message translates to:
  /// **'Governate'**
  String get governate;

  /// No description provided for @city.
  ///
  /// In en, this message translates to:
  /// **'City'**
  String get city;

  /// No description provided for @state.
  ///
  /// In en, this message translates to:
  /// **'state'**
  String get state;

  /// No description provided for @postalCode.
  ///
  /// In en, this message translates to:
  /// **'Postal Code'**
  String get postalCode;

  /// No description provided for @buildingNo.
  ///
  /// In en, this message translates to:
  /// **'Building Number'**
  String get buildingNo;

  /// No description provided for @floorNo.
  ///
  /// In en, this message translates to:
  /// **'Floor'**
  String get floorNo;

  /// No description provided for @apartmentNo.
  ///
  /// In en, this message translates to:
  /// **'Apartment'**
  String get apartmentNo;

  /// No description provided for @gettingLocation.
  ///
  /// In en, this message translates to:
  /// **'Getting Location'**
  String get gettingLocation;

  /// No description provided for @useCurrentLocation.
  ///
  /// In en, this message translates to:
  /// **'Use Current Location'**
  String get useCurrentLocation;

  /// No description provided for @locationObtained.
  ///
  /// In en, this message translates to:
  /// **'Location Obtained'**
  String get locationObtained;

  /// No description provided for @detailedAddress.
  ///
  /// In en, this message translates to:
  /// **'Detailed Address'**
  String get detailedAddress;

  /// No description provided for @updateAddress.
  ///
  /// In en, this message translates to:
  /// **'Update Address'**
  String get updateAddress;

  /// No description provided for @saveAddress.
  ///
  /// In en, this message translates to:
  /// **'Save Address'**
  String get saveAddress;

  /// No description provided for @saveInvoice.
  ///
  /// In en, this message translates to:
  /// **'Save Invoice'**
  String get saveInvoice;

  /// No description provided for @permissionDenied.
  ///
  /// In en, this message translates to:
  /// **'Permission Denied'**
  String get permissionDenied;

  /// No description provided for @addAddress.
  ///
  /// In en, this message translates to:
  /// **'Add Address'**
  String get addAddress;

  /// No description provided for @deletingAccountWill.
  ///
  /// In en, this message translates to:
  /// **'Deleting your account will remove all your personal data, including favorites, payment methods, and address information.'**
  String get deletingAccountWill;

  /// No description provided for @areYouSureDeleteAccount.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete your account?!'**
  String get areYouSureDeleteAccount;

  /// No description provided for @areYouSureDelete.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete'**
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
  /// **'at least 6 characters'**
  String get shortPassword;

  /// No description provided for @invalidEmail.
  ///
  /// In en, this message translates to:
  /// **'Invalid email'**
  String get invalidEmail;

  /// No description provided for @passwordMismatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords mismatch'**
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
  /// **'Choose Image Source'**
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
  /// **'Current password'**
  String get oldPassword;

  /// No description provided for @createYourAccountNow.
  ///
  /// In en, this message translates to:
  /// **'Create your account now and get points for every purchase you can use later as credit or discounts'**
  String get createYourAccountNow;

  /// No description provided for @weight.
  ///
  /// In en, this message translates to:
  /// **'Weight'**
  String get weight;

  /// No description provided for @dimensions.
  ///
  /// In en, this message translates to:
  /// **'Dimensions'**
  String get dimensions;

  /// No description provided for @emptySearch.
  ///
  /// In en, this message translates to:
  /// **'Search is empty'**
  String get emptySearch;

  /// No description provided for @nothingSearched.
  ///
  /// In en, this message translates to:
  /// **'Nothing searched yet .....!'**
  String get nothingSearched;

  /// No description provided for @noResultsFound.
  ///
  /// In en, this message translates to:
  /// **'No results found ..... !'**
  String get noResultsFound;

  /// No description provided for @cartIsEmpty.
  ///
  /// In en, this message translates to:
  /// **'Cart is empty.'**
  String get cartIsEmpty;

  /// No description provided for @everyProjectStartsWith.
  ///
  /// In en, this message translates to:
  /// **'Every project starts with a step... Add your first product now'**
  String get everyProjectStartsWith;

  /// No description provided for @reviews.
  ///
  /// In en, this message translates to:
  /// **'Reviews'**
  String get reviews;

  /// No description provided for @addReview.
  ///
  /// In en, this message translates to:
  /// **'What do you think?'**
  String get addReview;

  /// No description provided for @reviewSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Review Submitted'**
  String get reviewSubmitted;

  /// No description provided for @reviewError.
  ///
  /// In en, this message translates to:
  /// **'couldn\'t submit review, try again later'**
  String get reviewError;

  /// No description provided for @theProductIs.
  ///
  /// In en, this message translates to:
  /// **'the product is ...'**
  String get theProductIs;

  /// No description provided for @pleaseEnterAComment.
  ///
  /// In en, this message translates to:
  /// **'tell us what you think'**
  String get pleaseEnterAComment;

  /// No description provided for @latestOffers.
  ///
  /// In en, this message translates to:
  /// **'Latest Offers'**
  String get latestOffers;

  /// No description provided for @noproductsfound.
  ///
  /// In en, this message translates to:
  /// **'No products found'**
  String get noproductsfound;

  /// No description provided for @nobrandsfound.
  ///
  /// In en, this message translates to:
  /// **'No brands found'**
  String get nobrandsfound;

  /// No description provided for @nocategoriesfound.
  ///
  /// In en, this message translates to:
  /// **'No categories found'**
  String get nocategoriesfound;

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
  /// **'Offers'**
  String get offers;

  /// No description provided for @upTo.
  ///
  /// In en, this message translates to:
  /// **'Up to'**
  String get upTo;

  /// No description provided for @noFavourites.
  ///
  /// In en, this message translates to:
  /// **'No favourites yet'**
  String get noFavourites;

  /// No description provided for @addToFavourites.
  ///
  /// In en, this message translates to:
  /// **'Start adding products to your favorites!'**
  String get addToFavourites;

  /// No description provided for @signinToaddFavourites.
  ///
  /// In en, this message translates to:
  /// **'Sign in to add favourites'**
  String get signinToaddFavourites;

  /// No description provided for @discount.
  ///
  /// In en, this message translates to:
  /// **'off'**
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
  /// **'options'**
  String get options;

  /// No description provided for @filtersApplied.
  ///
  /// In en, this message translates to:
  /// **'filters applied'**
  String get filtersApplied;

  /// No description provided for @required.
  ///
  /// In en, this message translates to:
  /// **'required'**
  String get required;

  /// No description provided for @invoice.
  ///
  /// In en, this message translates to:
  /// **'invoice'**
  String get invoice;

  /// No description provided for @paymentDetails.
  ///
  /// In en, this message translates to:
  /// **'Payment Details'**
  String get paymentDetails;

  /// No description provided for @successfulPayment.
  ///
  /// In en, this message translates to:
  /// **'Successful Payment'**
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

  /// No description provided for @notes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get notes;

  /// No description provided for @processing.
  ///
  /// In en, this message translates to:
  /// **'processing...'**
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

  /// No description provided for @selectDeliveryAddress.
  ///
  /// In en, this message translates to:
  /// **'Select delivery address'**
  String get selectDeliveryAddress;

  /// No description provided for @addYourFirstAddressToGetStarted.
  ///
  /// In en, this message translates to:
  /// **'Add your first address to get started'**
  String get addYourFirstAddressToGetStarted;

  /// No description provided for @reason.
  ///
  /// In en, this message translates to:
  /// **'Reason'**
  String get reason;

  /// No description provided for @refundReasonDamaged.
  ///
  /// In en, this message translates to:
  /// **'Damaged'**
  String get refundReasonDamaged;

  /// No description provided for @refundReasonWrongItem.
  ///
  /// In en, this message translates to:
  /// **'Wrong Item'**
  String get refundReasonWrongItem;

  /// No description provided for @refundReasonNotAsDescribed.
  ///
  /// In en, this message translates to:
  /// **'Not as Described'**
  String get refundReasonNotAsDescribed;

  /// No description provided for @refundReasonOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get refundReasonOther;

  /// No description provided for @selectReason.
  ///
  /// In en, this message translates to:
  /// **'Select Reason:'**
  String get selectReason;

  /// No description provided for @selectAtLeastOneItem.
  ///
  /// In en, this message translates to:
  /// **'Please select at least one item'**
  String get selectAtLeastOneItem;

  /// No description provided for @pleaseEnterReason.
  ///
  /// In en, this message translates to:
  /// **'Please enter a reason'**
  String get pleaseEnterReason;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}

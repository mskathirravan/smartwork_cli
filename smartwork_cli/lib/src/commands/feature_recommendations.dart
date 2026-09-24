import 'project_type.dart';

class FeatureRecommendation {
  final String id;
  final String label;

  const FeatureRecommendation(this.id, this.label);
}

class FeatureRecommendations {
  static List<FeatureRecommendation> forType(ProjectType type) =>
      _table[type] ?? const [];

  static const Map<ProjectType, List<FeatureRecommendation>> _table = {
    ProjectType.eCommerce: [
      FeatureRecommendation('authentication', 'Authentication'),
      FeatureRecommendation('product_catalog', 'Product Catalog'),
      FeatureRecommendation('product_details', 'Product Details'),
      FeatureRecommendation('cart', 'Cart'),
      FeatureRecommendation('wishlist', 'Wishlist'),
      FeatureRecommendation('search', 'Search'),
      FeatureRecommendation('payment', 'Payment'),
      FeatureRecommendation('orders', 'Orders'),
      FeatureRecommendation('profile', 'Profile'),
    ],
    ProjectType.foodDelivery: [
      FeatureRecommendation('authentication', 'Authentication'),
      FeatureRecommendation('restaurant_listing', 'Restaurant Listing'),
      FeatureRecommendation('restaurant_details', 'Restaurant Details'),
      FeatureRecommendation('menu', 'Menu'),
      FeatureRecommendation('cart', 'Cart'),
      FeatureRecommendation('address', 'Address'),
      FeatureRecommendation('order_tracking', 'Order Tracking'),
      FeatureRecommendation('payment', 'Payment'),
      FeatureRecommendation('orders', 'Orders'),
      FeatureRecommendation('profile', 'Profile'),
    ],
    ProjectType.booking: [
      FeatureRecommendation('authentication', 'Authentication'),
      FeatureRecommendation('search', 'Search'),
      FeatureRecommendation('listing', 'Listing'),
      FeatureRecommendation('details', 'Details'),
      FeatureRecommendation('availability', 'Availability'),
      FeatureRecommendation('booking', 'Booking'),
      FeatureRecommendation('payment', 'Payment'),
      FeatureRecommendation('booking_history', 'Booking History'),
      FeatureRecommendation('profile', 'Profile'),
    ],
    ProjectType.social: [
      FeatureRecommendation('authentication', 'Authentication'),
      FeatureRecommendation('feed', 'Feed'),
      FeatureRecommendation('profile', 'Profile'),
      FeatureRecommendation('follow', 'Follow'),
      FeatureRecommendation('post', 'Post'),
      FeatureRecommendation('comments', 'Comments'),
      FeatureRecommendation('likes', 'Likes'),
      FeatureRecommendation('notifications', 'Notifications'),
      FeatureRecommendation('messaging', 'Messaging'),
    ],
    ProjectType.dashboard: [
      FeatureRecommendation('authentication', 'Authentication'),
      FeatureRecommendation('dashboard', 'Dashboard'),
      FeatureRecommendation('analytics', 'Analytics'),
      FeatureRecommendation('charts', 'Charts'),
      FeatureRecommendation('notifications', 'Notifications'),
      FeatureRecommendation('profile', 'Profile'),
      FeatureRecommendation('settings', 'Settings'),
    ],
    ProjectType.eBook: [
      FeatureRecommendation('authentication', 'Authentication'),
      FeatureRecommendation('book_catalog', 'Book Catalog'),
      FeatureRecommendation('book_details', 'Book Details'),
      FeatureRecommendation('search', 'Search'),
      FeatureRecommendation('categories', 'Categories'),
      FeatureRecommendation('reader', 'Reader'),
      FeatureRecommendation('bookmarks', 'Bookmarks'),
      FeatureRecommendation('reading_history', 'Reading History'),
      FeatureRecommendation('favorites', 'Favorites'),
      FeatureRecommendation('profile', 'Profile'),
    ],
    ProjectType.finance: [
      FeatureRecommendation('authentication', 'Authentication'),
      FeatureRecommendation('accounts', 'Accounts'),
      FeatureRecommendation('transactions', 'Transactions'),
      FeatureRecommendation('categories', 'Categories'),
      FeatureRecommendation('budget', 'Budget'),
      FeatureRecommendation('payments', 'Payments'),
      FeatureRecommendation('reports', 'Reports'),
      FeatureRecommendation('notifications', 'Notifications'),
      FeatureRecommendation('profile', 'Profile'),
    ],
  };
}

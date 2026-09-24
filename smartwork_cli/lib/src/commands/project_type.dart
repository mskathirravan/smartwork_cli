enum ProjectType {
  eCommerce,
  foodDelivery,
  booking,
  social,
  dashboard,
  eBook,
  finance,
  custom,
}

extension ProjectTypeDisplay on ProjectType {
  String get displayName => switch (this) {
        ProjectType.eCommerce => 'E-Commerce',
        ProjectType.foodDelivery => 'Food Delivery',
        ProjectType.booking => 'Booking',
        ProjectType.social => 'Social',
        ProjectType.dashboard => 'Dashboard',
        ProjectType.eBook => 'E-Book',
        ProjectType.finance => 'Finance',
        ProjectType.custom => 'Custom',
      };
}

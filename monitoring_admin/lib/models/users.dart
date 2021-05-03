class User {
  int id;
  String userID;
  String fullname;
  String phoneNumber;
  String idNumber;
  String idPicture;
  String profilePicture;
  String residence;
  String gender;
  String creationDate;
  bool active;
  bool suspended;
  bool isConfirmed;

  User({
    this.id = 0,
    this.userID = '',
    this.fullname = '',
    this.phoneNumber = '',
    this.idNumber = '',
    this.idPicture = '',
    this.profilePicture = '',
    this.residence = '',
    this.gender = '',
    this.creationDate = '',
    this.active = true,
    this.suspended = false,
    this.isConfirmed = false,
  });

  factory User.fromMap(Map<String, dynamic> map) => User(
        id: map["id"],
        userID: map["user_id"],
        fullname: map["fullname"],
        phoneNumber: map["phone_number"],
        idNumber: map["id_number"],
        idPicture: map["id_picture"],
        profilePicture: map["profile_picture"],
        residence: map["residence"],
        gender: map["gender"],
        creationDate: map["created_at"],
        active: map["active"],
        suspended: map["suspended"],
        isConfirmed: map["is_confirmed"],
      );

  static Map<String, dynamic> toMap(User user) => {
        'id': user.id,
        'user_id': user.userID,
        'fullname': user.fullname,
        'phone_number': user.phoneNumber,
        'id_number': user.idNumber,
        'id_picture': user.idPicture,
        'profile_picture': user.profilePicture,
        'residence': user.residence,
        'gender': user.gender,
        'created_at': user.creationDate,
        'active': user.active,
        'suspended': user.suspended,
        'is_confirmed': user.isConfirmed,
      };

  @override
  String toString() => 'User: $userID';
}

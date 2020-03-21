Deface::Override.new(
  virtual_path: 'account/register',
  name: 'add-invisble-captcha',
  insert_top: 'div.box',
  original: Redmine::VERSION.to_s >= '4.1' ? 'a9c303821376a8d83cba32654629d71cc3926a1d' : 'e64d82c46cc3322e4d953aa119d1e71e81854158',
  partial: 'account/invisible_captcha'
)

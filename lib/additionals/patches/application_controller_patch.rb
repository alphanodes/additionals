require_dependency 'application_controller'

class ApplicationController
  before_action :enable_smileys

  def enable_smileys
    return if Redmine::WikiFormatting::Textile::Formatter::RULES.include?(:inline_smileys) ||
              !Additionals.setting?(:legacy_smiley_support)

    Redmine::WikiFormatting::Textile::Formatter::RULES << :inline_smileys
  end
end

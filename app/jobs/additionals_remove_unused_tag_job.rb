class AdditionalsRemoveUnusedTagJob < AdditionalsJob
  def perform
    AdditionalsTag.remove_unused_tags
  end
end

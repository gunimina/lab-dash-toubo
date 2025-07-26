# frozen_string_literal: true

class ApplicationComponent < ViewComponent::Base
  include ApplicationHelper
  
  private
  
  # 안전한 Tailwind 클래스 병합
  def safe_classes(*classes)
    classes.compact.join(' ')
  end
  
  # DOM ID 생성 헬퍼
  def dom_id(object, prefix = nil)
    return prefix.to_s if object.nil?
    
    name = object.class.name.underscore.tr('/', '_')
    id = object.try(:id) || object.object_id
    
    [prefix, name, id].compact.join('_')
  end
end
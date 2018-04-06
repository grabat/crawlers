module StandardClassMethods
  def self.included(base)
    base.extend(ClassMethods)
  end

  module ClassMethods
    def call
      new.call
    end
  end
end

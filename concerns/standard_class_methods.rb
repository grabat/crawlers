module StandardClassMethods
  def self.included(base)
    base.extend(ClassMethods)
  end

  module ClassMethods
    def run
      new.run
    end
  end
end

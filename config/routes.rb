Rails.application.routes.draw do
  namespace :sparkle do
    resources :builders do
      collection do
        get 'property-populator', :to => :property_populator, :as => :property_populator
        post 'validate', :to => :validate, :as => :validator
        post 'build-json', :to => :build_json, :as => :build_json
      end
      post 'build-target', :to => :build_target, :as => :build_target
    end
  end
end

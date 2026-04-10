# frozen_string_literal: true

Rails.application.routes.draw do
  resources :issues, only: [] do
    resource 'assign_to_me', only: %i[update], controller: 'additionals_assign_to_me'
    resource 'change_status', only: %i[update], controller: 'additionals_change_status'
  end

  resource :dashboard_async_blocks, only: %i[show create]

  resources :dashboards do
    member do
      post :update_layout_setting
      post :add_block
      post :remove_block
      post :order_blocks
      put :lock
      put :unlock
    end
  end

  resources :projects, only: [] do
    resources :dashboards do
      member do
        post :update_layout_setting
        post :add_block
        post :remove_block
        post :order_blocks
        put :lock
        put :unlock
      end
    end
    resource :dashboard_async_blocks, only: %i[show create]
  end

  resource :global_search, only: [], controller: 'global_search' do
    get :search, on: :collection
  end

  resource :additionals_macros, only: :show, path: '/help/macros'

  resources :auto_completes, only: [] do
    collection do
      get :fontawesome
      get :issue_assignee
      get :assignee
      get :authors
      get :grouped_principals
      get :grouped_users
      get :custom_field_users
    end
  end
end

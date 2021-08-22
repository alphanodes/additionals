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
    end
  end

  resources :projects, only: [] do
    resources :dashboards do
      member do
        post :update_layout_setting
        post :add_block
        post :remove_block
        post :order_blocks
      end
    end
    resource :dashboard_async_blocks, only: %i[show create]
  end

  resource :additionals_macros, only: :show, path: '/help/macros'

  resources :auto_completes, only: [] do
    collection do
      get :issue_assignee
      get :global_users
      get :fontawesome
    end
  end
end

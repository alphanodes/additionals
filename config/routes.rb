# Plugin's routes
# See: http://guides.rubyonrails.org/routing.html

match 'garfield/:name/:type', to: 'garfield#show', via: :get

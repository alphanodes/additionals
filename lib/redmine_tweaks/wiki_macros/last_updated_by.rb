# Wiki Extensions plugin for Redmine
# Copyright (C) 2009-2012  Haruyuki Iida
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

# Last_updated_by wiki macros
module RedmineTweaks
  module WikiMacros
    Redmine::WikiFormatting::Macros.register do
      desc <<-EOHELP
      Displays a user who updated the page.
        {{last_updated_by}}
      EOHELP

      macro :last_updated_by do |obj, args|
        fail 'The correct usage is {{last_updated_by}}' if args.length > 0
        content_tag(:span,
                    "#{avatar(obj.author, size: 14)} #{link_to_user(obj.author)}".html_safe,
                    class: 'last-updated-by')
      end
    end
  end
end

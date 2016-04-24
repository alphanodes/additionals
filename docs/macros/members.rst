Members
-------

Project members macro for Redmine.

#### Description

* {{members}} := lists all members of the current users project
* {{members(123)}} or {{members(identifier)}} or {{members(My project)}} := Lists all members of the project with project id 123 (or identifier or project name)
* {{members(123, title=Manager)}} := Lists all members of the project with project id 123 and the role "Manager". If you want to use multiple roles as filters, you have to use a | as separator.
* {{members(123, title=Manager, role=Manager only)}} := Lists all members of the project with project id 123 and the role "Manager" and adds the heading "Manager only"

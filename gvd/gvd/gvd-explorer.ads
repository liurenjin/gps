-----------------------------------------------------------------------
--                 Odd - The Other Display Debugger                  --
--                                                                   --
--                         Copyright (C) 2000                        --
--                 Emmanuel Briot and Arnaud Charlet                 --
--                                                                   --
-- Odd is free  software;  you can redistribute it and/or modify  it --
-- under the terms of the GNU General Public License as published by --
-- the Free Software Foundation; either version 2 of the License, or --
-- (at your option) any later version.                               --
--                                                                   --
-- This program is  distributed in the hope that it will be  useful, --
-- but  WITHOUT ANY WARRANTY;  without even the  implied warranty of --
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU --
-- General Public License for more details. You should have received --
-- a copy of the GNU General Public License along with this library; --
-- if not,  write to the  Free Software Foundation, Inc.,  59 Temple --
-- Place - Suite 330, Boston, MA 02111-1307, USA.                    --
-----------------------------------------------------------------------

with Gtk.Ctree;
with Gtk.Widget;
with Language;
with Gtk.Style;
with Odd.Types;
with Gdk.Pixmap;
with Gdk.Bitmap;

--  This package implements a file explorer and browser.
--  It shows all the files that belong to the current application, and makes
--  it possible to browse the list of entities defined in each of these files.
--  The files are organized into several categories:
--     - File extension
--     - System and user files

package Odd.Explorer is

   type Explorer_Record is new Gtk.Ctree.Gtk_Ctree_Record with private;
   type Explorer_Access is access all Explorer_Record'Class;

   type Position_Type is record
      Line, Column, Index : Natural;
   end record;

   procedure Gtk_New
     (Explorer    : out Explorer_Access;
      Code_Editor : access Gtk.Widget.Gtk_Widget_Record'Class);
   --  Create a new explorer

   type Explorer_Handler is access
     procedure
       (Widget   : access Explorer_Record'Class;
        Position : Position_Type);
   --  Handler called when an item is selected in the tree.
   --  Index is the position in the buffer where the selected entity
   --  starts.
   --  Widget is the Window parameter given to Explore below.

   procedure Explore
     (Tree      : access Explorer_Record;
      Root      : Gtk.Ctree.Gtk_Ctree_Node;
      Window    : access Gtk.Widget.Gtk_Widget_Record'Class;
      Buffer    : String;
      Lang      : Language.Language_Access;
      File_Name : String);
   --  Parse the entities present in buffer.
   --  The items for the explorer are added to Tree, as children of the
   --  Root Node
   --  See Explorer_Handler above for a description of Handler.

   procedure Add_File_Node
     (Tree      : access Explorer_Record;
      File_Name : String);
   --  Insert a node for a new file.

   procedure Add_List_Of_Files
     (Tree : access Explorer_Record;
      List : Odd.Types.String_Array);
   --  Add several files in the explorer if there are not already there.

   procedure Set_Current_File
     (Tree : access Explorer_Record;
      File_Name : String);
   --  Set a new current file.
   --  The entry in the tree for this file is made visible, and highlighted.

private
   type Explorer_Record is new Gtk.Ctree.Gtk_Ctree_Record with record
      Explorer_Root      : Gtk.Ctree.Gtk_Ctree_Node;
      Code_Editor        : Gtk.Widget.Gtk_Widget;
      Current_File_Style : Gtk.Style.Gtk_Style;
      File_Name_Style    : Gtk.Style.Gtk_Style;
      Current_File_Node  : Gtk.Ctree.Gtk_Ctree_Node;

      Folder_Pixmap      : Gdk.Pixmap.Gdk_Pixmap;
      Folder_Mask        : Gdk.Bitmap.Gdk_Bitmap;
      Folder_Open_Pixmap : Gdk.Pixmap.Gdk_Pixmap;
      Folder_Open_Mask   : Gdk.Bitmap.Gdk_Bitmap;
   end record;
end Odd.Explorer;

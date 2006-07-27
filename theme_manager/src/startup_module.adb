-----------------------------------------------------------------------
--                               G P S                               --
--                                                                   --
--                     Copyright (C) 2006 AdaCore                    --
--                                                                   --
-- GPS is free  software;  you can redistribute it and/or modify  it --
-- under the terms of the GNU General Public License as published by --
-- the Free Software Foundation; either version 2 of the License, or --
-- (at your option) any later version.                               --
--                                                                   --
-- This program is  distributed in the hope that it will be  useful, --
-- but  WITHOUT ANY WARRANTY;  without even the  implied warranty of --
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU --
-- General Public License for more details. You should have received --
-- a copy of the GNU General Public License along with this program; --
-- if not,  write to the  Free Software Foundation, Inc.,  59 Temple --
-- Place - Suite 330, Boston, MA 02111-1307, USA.                    --
-----------------------------------------------------------------------

with Ada.Unchecked_Conversion;
with Commands.Custom;      use Commands, Commands.Custom;
with Commands.Interactive; use Commands.Interactive;
with Glib.Object;          use Glib, Glib.Object;
with Glib.Values;          use Glib.Values;
with Glib.Xml_Int;         use Glib.Xml_Int;
with GNAT.OS_Lib;          use GNAT.OS_Lib;
with GPS.Kernel;           use GPS.Kernel;
with GPS.Kernel.Custom;    use GPS.Kernel.Custom;
with GPS.Kernel.Modules;   use GPS.Kernel.Modules;
with GPS.Intl;             use GPS.Intl;
with Gtkada.Handlers;      use Gtkada.Handlers;
with Gtk.Box;              use Gtk.Box;
with Gtk.Cell_Renderer;    use Gtk.Cell_Renderer;
with Gtk.Dialog;           use Gtk.Dialog;
with Gtk.Enums;            use Gtk.Enums;
with Gtk.Event_Box;        use Gtk.Event_Box;
with Gtk.Label;            use Gtk.Label;
with Gtk.Notebook;         use Gtk.Notebook;
with Gtk.Paned;            use Gtk.Paned;
with Gtk.Scrolled_Window;  use Gtk.Scrolled_Window;
with Gtk.Stock;            use Gtk.Stock;
with Gtk.Text_Buffer;      use Gtk.Text_Buffer;
with Gtk.Text_Iter;        use Gtk.Text_Iter;
with Gtk.Text_Tag;         use Gtk.Text_Tag;
with Gtk.Text_View;        use Gtk.Text_View;
with Gtk.Tree_View_Column; use Gtk.Tree_View_Column;
with Gtk.Tree_Model;       use Gtk.Tree_Model;
with Gtk.Tree_Selection;   use Gtk.Tree_Selection;
with Gtk.Tree_Store;       use Gtk.Tree_Store;
with Gtk.Tree_View;        use Gtk.Tree_View;
with Gtk.Widget;           use Gtk.Widget;
with GUI_Utils;            use GUI_Utils;
with Pango.Enums;          use Pango.Enums;
with System;               use System;
with VFS;                  use VFS;

package body Startup_Module is

   procedure On_Edit_Startup_Scripts
     (Widget : access GObject_Record'Class; Kernel : Kernel_Handle);
   --  Called when the user selects the menu to edit startup scripts

   Column_Load       : constant := 0;
   Column_Name       : constant := 1;
   Column_Explicit   : constant := 2;
   Column_File       : constant := 3;
   Column_Initialize : constant := 4;
   Column_Modified   : constant := 5;

   type Startup_Editor_Record is new Gtk_Dialog_Record with record
      Kernel      : Kernel_Handle;
      Tree        : Gtk_Tree_View;
      Model       : Gtk_Tree_Store;
      Description : Gtk_Text_Buffer;
      Script_Name : Gtk_Label;
      Init        : Gtk_Box;
   end record;
   type Startup_Editor is access all Startup_Editor_Record'Class;

   procedure Gtk_New
     (Editor : out Startup_Editor;
      Kernel : access Kernel_Handle_Record'Class);
   --  Initialize a new editor

   procedure On_Selection_Changed (Editor : access Gtk_Widget_Record'Class);
   --  Called when the selection in the tree has changed.

   procedure On_Load_Toggled
     (Editor : access Gtk_Widget_Record'Class;
      Params : Glib.Values.GValues);
   --  Toggled when the loading status of a script is changed.

   procedure Save (Editor : access Startup_Editor_Record'Class);
   --  Save the changes done in Editor into the kernel

   function "+" is new Ada.Unchecked_Conversion
     (Glib.Xml_Int.Node_Ptr, System.Address);
   function "+" is new Ada.Unchecked_Conversion
     (System.Address, Glib.Xml_Int.Node_Ptr);

   --------------------------
   -- On_Selection_Changed --
   --------------------------

   procedure On_Selection_Changed (Editor : access Gtk_Widget_Record'Class) is
      Ed         : constant Startup_Editor := Startup_Editor (Editor);
      Selection  : constant Gtk_Tree_Selection := Get_Selection (Ed.Tree);
      Model      : Gtk_Tree_Model;
      Iter       : Gtk_Tree_Iter;
      Bold       : Gtk_Text_Tag;
      Text_Iter  : Gtk_Text_Iter;
      Contents   : String_Access;
      File       : VFS.Virtual_File := VFS.No_File;
      Init       : Glib.Xml_Int.Node_Ptr;
      XML_Editor : Gtk_Widget;
      XML_Added  : Boolean := False;
      Label      : Gtk_Label;
      Command    : Custom_Command_Access;
      Component_Iter : Component_Iterator;
      Component      : Command_Component;
   begin
      Get_Selected (Selection, Model, Iter);
      if Iter /= Null_Iter then
         Set_Text (Ed.Script_Name, Get_String (Model, Iter, Column_Name));

         Set_Text (Ed.Description, "");
         Get_End_Iter (Ed.Description, Text_Iter);

         Bold := Create_Tag (Ed.Description);
         Set_Property (Bold, Gtk.Text_Tag.Weight_Property, Pango_Weight_Bold);

         Insert_With_Tags (Ed.Description, Text_Iter, -"File: ", Bold);
         if Get_String (Model, Iter, Column_File) = "" then
            Insert (Ed.Description, Text_Iter, -"<not found>" & ASCII.LF);
         else
            File := Create (Full_Filename =>
                              Get_String (Model, Iter, Column_File));
            Insert (Ed.Description, Text_Iter,
                    Full_Name (File).all & ASCII.LF);
         end if;

         Insert_With_Tags (Ed.Description, Text_Iter,
                           -"Loaded at startup: ", Bold);
         if Get_Boolean (Model, Iter, Column_Load) then
            Insert (Ed.Description, Text_Iter, -"yes" & ASCII.LF);
         else
            Insert (Ed.Description, Text_Iter, -"no" & ASCII.LF);
         end if;

         Insert_With_Tags (Ed.Description, Text_Iter,
                           -"   why: ", Bold);
         if Get_Boolean (Model, Iter, Column_Modified) then
            Insert (Ed.Description, Text_Iter,
                    -"Modified in this dialog -- Press Cancel to revert"
                    & ASCII.LF);
         elsif Get_Boolean (Model, Iter, Column_Explicit) then
            Insert (Ed.Description, Text_Iter,
                    -"explicitly set by user" & ASCII.LF);
         elsif Get_Boolean (Model, Iter, Column_Load) then
            Insert (Ed.Description, Text_Iter,
                    -"found in auto-loading directory" & ASCII.LF);
         else
            Insert (Ed.Description, Text_Iter,
                    -"found in no auto-loading directory" & ASCII.LF);
         end if;

         Contents := Read_File (File);
         if Contents /= null then
            Insert_With_Tags
              (Ed.Description, Text_Iter,
               (-"Description and script:") & ASCII.LF,
               Bold);
            Insert (Ed.Description, Text_Iter, Contents.all);
            Free (Contents);
         end if;

         Remove_All_Children (Ed.Init);
         Init := +Get_Address (Model, Iter, Column_Initialize);

         if Init /= null then
            Command := new Custom_Command;
            Create
              (Item                 => Command,
               Name                 => Get_String (Model, Iter, Column_Name),
               Kernel               => Ed.Kernel,
               Command              => Init,
               Default_Output       => No_Output,
               Show_Command         => False,
               Show_In_Task_Manager => False);

            Component_Iter := Start (Command);
            loop
               Component := Get (Component_Iter);
               exit when Component = null;
               XML_Editor := Component_Editor (Ed.Kernel, Component);
               Pack_Start (Ed.Init, XML_Editor, Expand => True, Fill => True);
               Set_Sensitive (XML_Editor, False);
               XML_Added := True;
               Next (Component_Iter);
            end loop;
            Free (Component_Iter);

            Destroy (Command_Access (Command));
         end if;

         if not XML_Added then
            Gtk_New (Label, -"No initialization commands defined");
            Pack_Start (Ed.Init, Label, Expand => True, Fill => True);
         end if;

         Show_All (Ed.Init);

      end if;
   end On_Selection_Changed;

   ----------
   -- Save --
   ----------

   procedure Save (Editor : access Startup_Editor_Record'Class) is
      Iter : Gtk_Tree_Iter;
   begin
      Iter := Get_Iter_First (Editor.Model);
      while Iter /= Null_Iter loop
         if Get_Boolean (Editor.Model, Iter, Column_Modified) then
            Override_Startup_Script
              (Kernel         => Editor.Kernel,
               Base_Name      => Get_String (Editor.Model, Iter, Column_Name),
               Load           => Get_Boolean (Editor.Model, Iter, Column_Load),
               Initialization => "");
         end if;

         Next (Editor.Model, Iter);
      end loop;
   end Save;

   ---------------------
   -- On_Load_Toggled --
   ---------------------

   procedure On_Load_Toggled
     (Editor : access Gtk_Widget_Record'Class;
      Params : Glib.Values.GValues)
   is
      Ed          : constant Startup_Editor := Startup_Editor (Editor);
      Path_String : constant String := Get_String (Nth (Params, 1));
      Iter        : Gtk_Tree_Iter;
   begin
      Iter := Get_Iter_From_String (Ed.Model, Path_String);
      Set (Ed.Model, Iter, Column_Modified, True);

      --  Refresh the description box
      On_Selection_Changed (Editor);
   end On_Load_Toggled;

   -------------
   -- Gtk_New --
   -------------

   procedure Gtk_New
     (Editor : out Startup_Editor;
      Kernel : access Kernel_Handle_Record'Class)
   is
      Button      : Gtk_Widget;
      Scrolled    : Gtk_Scrolled_Window;
      Iter        : Gtk_Tree_Iter;
      Box         : Gtk_Box;
      Pane        : Gtk_Paned;
      Text        : Gtk_Text_View;
      Event       : Gtk_Event_Box;
      Note        : Gtk_Notebook;
      Script_Iter : Script_Iterator;
      Script      : Script_Description;
      List        : Cell_Renderer_List.Glist;
      Label       : Gtk_Label;
      pragma Unreferenced (Button);

      Load_Cst : aliased String := -"Load";
      Name_Cst : aliased String := -"Script name";
   begin
      Editor := new Startup_Editor_Record;
      Editor.Kernel := Kernel_Handle (Kernel);
      Initialize
        (Editor,
         Title  => -"Edit Startup Scripts",
         Parent => Get_Main_Window (Kernel),
         Flags  => Destroy_With_Parent);
      Set_Default_Size (Editor, 800, 600);

      Gtk_New_Hpaned (Pane);
      Pack_Start (Get_Vbox (Editor), Pane, Expand => True, Fill => True);

      Gtk_New (Scrolled);
      Pack1 (Pane, Scrolled, True, True);
      Set_Size_Request (Scrolled, 200, -1);
      Set_Policy (Scrolled, Policy_Automatic, Policy_Automatic);

      Editor.Tree := Create_Tree_View
        (Column_Types => (Column_Load       => GType_Boolean,
                          Column_Name       => GType_String,
                          Column_Explicit   => GType_Boolean,
                          Column_File       => GType_String,
                          Column_Initialize => GType_Pointer,
                          Column_Modified   => GType_Boolean),
         Column_Names => (Column_Load + 1 => Load_Cst'Unchecked_Access,
                          Column_Name + 1 => Name_Cst'Unchecked_Access),
         Show_Column_Titles => True,
         Initial_Sort_On    => Column_Name + 1);
      Add (Scrolled, Editor.Tree);

      Gtk_New_Vbox (Box, Homogeneous => False);
      Pack2 (Paned => Pane, Child => Box, Resize => True, Shrink => True);
      Set_Size_Request (Box, 600, -1);

      Create_Blue_Label (Editor.Script_Name, Event);
      Pack_Start (Box, Event, Expand => False);

      Gtk_New (Note);
      Pack_Start (Box, Note, Expand => True, Fill => True);

      Gtk_New (Scrolled);
      Gtk_New (Label, -"Description");
      Append_Page (Note, Scrolled, Label);
      Set_Policy (Scrolled, Policy_Automatic, Policy_Automatic);

      Gtk_New (Editor.Description);
      Gtk_New (Text, Editor.Description);
      Add (Scrolled, Text);
      Set_Wrap_Mode (Text, Wrap_Word);
      Set_Editable (Text, False);

      Gtk_New (Scrolled);
      Gtk_New (Label, -"Initialization");
      Append_Page (Note, Scrolled, Label);
      Set_Policy (Scrolled, Policy_Automatic, Policy_Automatic);

      Gtk_New_Vbox (Editor.Init);
      Add (Scrolled, Editor.Init);

      List := Get_Cell_Renderers (Get_Column (Editor.Tree, Column_Load));
      Widget_Callback.Object_Connect
        (Cell_Renderer_List.Get_Data (List), "toggled",
         On_Load_Toggled'Access, Editor, After => True);
      Cell_Renderer_List.Free (List);

      Widget_Callback.Object_Connect
        (Get_Selection (Editor.Tree), "changed",
         On_Selection_Changed'Access, Editor);

      Editor.Model := Gtk_Tree_Store (Get_Model (Editor.Tree));
      Get_First_Startup_Script (Kernel, Script_Iter);
      while not At_End (Script_Iter) loop
         Script := Get (Script_Iter);

         Append (Editor.Model, Iter, Null_Iter);
         Set (Editor.Model, Iter, Column_Load, Get_Load (Script));
         Set (Editor.Model, Iter, Column_Name, Get_Script (Script_Iter));
         Set (Editor.Model, Iter, Column_Explicit, Get_Explicit (Script));
         Set (Editor.Model, Iter, Column_File,
              Full_Name (Get_Full_File (Script)).all);
         Set (Editor.Model, Iter, Column_Modified, False);
         Set (Editor.Model, Iter, Column_Initialize, +Get_Init (Script));

         Next (Script_Iter);
      end loop;

      Select_Iter (Get_Selection (Editor.Tree), Get_Iter_First (Editor.Model));

      Button := Add_Button (Editor, Stock_Ok, Gtk_Response_OK);
      Button := Add_Button (Editor, Stock_Cancel, Gtk_Response_Cancel);
   end Gtk_New;

   -----------------------------
   -- On_Edit_Startup_Scripts --
   -----------------------------

   procedure On_Edit_Startup_Scripts
     (Widget : access GObject_Record'Class; Kernel : Kernel_Handle)
   is
      pragma Unreferenced (Widget);
      Editor : Startup_Editor;
   begin
      Gtk_New (Editor, Kernel);

      Show_All (Editor);
      if Run (Editor) = Gtk_Response_OK then
         Save (Editor);
      end if;
      Destroy (Editor);
   end On_Edit_Startup_Scripts;

   ---------------------
   -- Register_Module --
   ---------------------

   procedure Register_Module
     (Kernel : access GPS.Kernel.Kernel_Handle_Record'Class)
   is
      Module : Module_ID;
   begin
      Module := new Module_ID_Record;
      Register_Module (Module, Kernel, "Startup scripts manager");

      Register_Menu
        (Kernel, '/' & (-"Edit"),
         -"S_tartup Scripts",
         Callback => On_Edit_Startup_Scripts'Access,
         Ref_Item => "Preferences",
         Add_Before => True);
   end Register_Module;

end Startup_Module;

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

with Odd.Strings; use Odd.Strings;
with Language.Debugger; use Language.Debugger;

with Ada.Text_IO; use Ada.Text_IO;

package body Debugger.Gdb.C is

   use Language;

   Record_Start : Character := '{';
   Record_End   : Character := '}';
   Array_Start  : Character := '{';
   Array_End    : Character := '}';
   Record_Field : String    := "=";
   --  how are record field names separated from their values

   ---------------------
   -- Break Exception --
   ---------------------

   function Break_Exception
     (Debugger  : access Gdb_C_Language;
      Name      : String  := "";
      Unhandled : Boolean := False) return String is
   begin
      --  ??? Unsupported, should we raise an exception, so that the menu
      --  can be disabled ?
      return "";
   end Break_Exception;

   ----------------
   -- Parse_Type --
   ----------------

   procedure Parse_Type
     (Lang     : access Gdb_C_Language;
      Type_Str : String;
      Entity   : String;
      Index    : in out Natural;
      Result   : out Generic_Type_Access)
   is
      Tmp  : Natural := Index;
      Save : Natural;
   begin

      --  First: Skip the type itself, to check whether we have in fact an
      --  array or access type.

      if Looking_At (Type_Str, Index, "struct ")
        or else Looking_At (Type_Str, Index, "union ")
      then
         Skip_To_Char (Type_Str, Index, Record_End);
         Index := Index + 1;
      else
         Skip_Word (Type_Str, Index);
      end if;
      Skip_Blanks (Type_Str, Index);

      --  Skip to the right-most access or array definition
      --  For instance, when looking at 'int* [4]' we should detect an array
      --  type, not an access type.

      Save := Index;
      while Index <= Type_Str'Last loop
         --  Access type ?
         if Type_Str (Index) = '*' then
            Save := Index;
            Index := Index + 1;

         --  Array type ?
         elsif Type_Str (Index) = '[' then
            --  Leave Index at the beginning of a multi-dimensional array, as
            --  in 'int [2][3]'.
            if Type_Str (Save) = '*' then
               Save := Index;
            end if;
            Skip_To_Char (Type_Str, Index, ']');
            Index := Index + 1;

         --  Access to subprogram
         elsif Type_Str (Index) = '('
           and then Type_Str (Index + 1) = '*'
         then
            --  Skip the field name (if any), as in: "void (*field1[2])();"
            Index := Index + 1;
            Save := Index;
            while Index <= Type_Str'Last
              and then Type_Str (Index) /= ')'
              and then Type_Str (Index) /= '['
            loop
               Index := Index + 1;
            end loop;

         else
            exit;
         end if;
         Skip_Blanks (Type_Str, Index);
      end loop;
      Index := Save;

      --  An access type ?
      if Index <= Type_Str'Last and then Type_Str (Index) = '*' then
         Index := Index + 1;
         Result := New_Access_Type;
         return;
      end if;

      --  An array type ?
      if Index < Type_Str'Last and then Type_Str (Index) = '[' then
         Parse_Array_Type (Lang, Type_Str, Entity, Tmp, Index, Result);
         Index := Tmp;
         return;
      end if;

      --  Else a simple type

      Index := Tmp;

      case Type_Str (Index) is
         when 'e' =>

            --  Enumeration type

            if Looking_At (Type_Str, Index, "enum ") then
               Skip_To_Char (Type_Str, Index, '}');
               Index := Index + 1;
               Result := New_Enum_Type;
               return;
            end if;
            --  Else falls through

         when 's' =>

            --  Structures.
            --  There are two possible cases here:
            --      "struct My_Record { ... }"
            --   or "struct My_Record a"
            --  The second case needs a further ptype to get the real
            --  definition.

            if Looking_At (Type_Str, Index, "struct ") then
               Tmp := Index;
               Index := Index + 7;           --  skips "struct "
               Skip_Word (Type_Str, Index);  --  skips struct name
               Skip_Blanks (Type_Str, Index);
               if Index <= Type_Str'Last
                 and then Type_Str (Index) = Record_Start
               then
                  Index := Index + 1;
                  Parse_Record_Type
                    (Lang, Type_Str, Entity, Index,
                     Is_Union => False, Result => Result, End_On => "}");
               else
                  Result := Parse_Type
                    (Get_Debugger (Lang), Type_Str (Tmp .. Index - 1));
               end if;
               return;
            end if;
            --  Else falls through

         when 'u' =>
            if Looking_At (Type_Str, Index, "union ") then
               Tmp := Index;
               Index := Index + 6;           --  skips "union "
               Skip_Word (Type_Str, Index);  --  skips union name
               Skip_Blanks (Type_Str, Index);
               if Index <= Type_Str'Last
                 and then Type_Str (Index) = Record_Start
               then
                  Index := Index + 1;
                  Parse_Record_Type
                    (Lang, Type_Str, Entity, Index, Is_Union => True,
                     Result => Result, End_On => "}");
               else
                  Result := Parse_Type
                    (Get_Debugger (Lang), Type_Str (Tmp .. Index - 1));
               end if;
               return;
            end if;
            --  Else falls through

         when others =>
            null;
      end case;

      --  Do we have a simple type ?

      if Is_Simple_Type (Lang, Type_Str (Tmp .. Type_Str'Last)) then
         Result := New_Simple_Type;
         return;
      end if;

      --  Else ask for more information

      Index := Tmp;
      Skip_Word (Type_Str, Index);

      declare
         T : String :=
           Type_Of (Get_Debugger (Lang), Type_Str (Tmp .. Index - 1));
         J : Natural := T'First;
      begin
         Parse_Type
           (Lang, T, Type_Str (Tmp .. Index - 1), J, Result);
         Index := Type_Str'Last;
      end;
   end Parse_Type;

   -----------------
   -- Parse_Value --
   -----------------

   procedure Parse_Value
     (Lang       : access Gdb_C_Language;
      Type_Str   : String;
      Index      : in out Natural;
      Result     : in out Generic_Values.Generic_Type_Access;
      Repeat_Num : out Positive)
   is
   begin
      Internal_Parse_Value (Lang, Type_Str, Index, Result, Repeat_Num,
                            Parent => null);
   end Parse_Value;

   ----------------------
   -- Parse_Array_Type --
   ----------------------

   procedure Parse_Array_Type
     (Lang      : access Gdb_C_Language;
      Type_Str  : String;
      Entity    : String;
      Index     : in out Natural;
      Start_Of_Dim : in Natural;
      Result    : out Generic_Type_Access)
   is
      Num_Dim   : Integer := 0;
      Initial   : Natural := Index;
      Tmp_Index : Natural;
      R         : Array_Type_Access;
      Last      : Long_Integer;
      Item_Type : Generic_Type_Access;
   begin

      --  Find the number of dimensions
      Index := Start_Of_Dim;
      Tmp_Index := Index;
      while Tmp_Index <= Type_Str'Last
        and then Type_Str (Tmp_Index) = '['
      loop
         Num_Dim := Num_Dim + 1;
         Skip_To_Char (Type_Str, Tmp_Index, ']');
         Tmp_Index := Tmp_Index + 1;
      end loop;

      --  Create the type

      Result := New_Array_Type (Num_Dimensions => Num_Dim);
      R := Array_Type_Access (Result);

      --  Then parse the dimensions.
      Num_Dim := 0;
      while Index <= Type_Str'Last
        and then Type_Str (Index) = '['
      loop
         Num_Dim := Num_Dim + 1;
         Index := Index + 1;
         Parse_Num (Type_Str, Index, Last);
         Set_Dimensions (R.all, Num_Dim, (0, Last - 1));
         Index := Index + 1;
      end loop;

      --  Finally parse the type of items

      Parse_Type (Lang,
                  Type_Str (Initial .. Start_Of_Dim - 1),
                  Array_Item_Name (Lang, Entity, "0"),
                  Initial,
                  Item_Type);
      Set_Item_Type (R.all, Item_Type);
   end Parse_Array_Type;

   -----------------------
   -- Parse_Record_Type --
   -----------------------

   procedure Parse_Record_Type
     (Lang      : access Gdb_C_Language;
      Type_Str  : String;
      Entity    : String;
      Index     : in out Natural;
      Is_Union  : Boolean;
      Result    : out Generic_Type_Access;
      End_On    : String)
   is
      Num_Fields : Natural := 0;
      Field      : Natural := 1;
      Initial    : constant Natural := Index;
      R          : Record_Type_Access;
      Field_Value : Generic_Type_Access;
      Tmp,
      Save,
      End_Of_Name : Natural;
   begin
      --  Count the number of fields

      while Index <= Type_Str'Last
        and then Type_Str (Index) /= '}'
      loop
         if Type_Str (Index) = ';' then
            Num_Fields := Num_Fields + 1;
         end if;
         Index := Index + 1;
      end loop;

      --  Create the type

      if Is_Union then
         Result := New_Union_Type (Num_Fields);
      else
         Result := New_Record_Type (Num_Fields);
      end if;
      R := Record_Type_Access (Result);

      --  Parse the type

      Index := Initial;
      while Field <= Num_Fields loop
         Skip_Blanks (Type_Str, Index);

         --  Get the field name (last word before ;)
         --  There is a small exception here for access-to-subprograms fields,
         --  which look like "void (*field1[2])();"
         --  gdb seems to ignore all the parameters to the function, so
         --  we take the simplest way and consider there is always '()' for
         --  the parameter list.

         Tmp := Index;
         Skip_To_Char (Type_Str, Index, ';');
         Save := Index;
         Index := Index - 1;

         if Type_Str (Index) = ')' then
            Index := Index - 2;
            Skip_To_Char (Type_Str, Index, '(', Step => -1);
            Index := Index + 1;
            End_Of_Name := Index + 2;
            Skip_Word (Type_Str, End_Of_Name);
         else

            --  The size of the field can optionally be indicated between the
            --  name and the semicolon, as in "__time_t tv_sec : 32;".
            --  We simply ignore the size.

            End_Of_Name := Save;
            Skip_Word (Type_Str, Index, Step => -1);
            if Type_Str (Index - 1) = ':' then
               Index := Index - 3;
               End_Of_Name := Index + 1;
               Skip_Word (Type_Str, Index, Step => -1);
            end if;
         end if;

         --  Create the field now that we have all the information.
         Set_Field_Name (R.all, Field, Type_Str (Index + 1 .. End_Of_Name - 1),
                         Variant_Parts => 0);
         Parse_Type
           (Lang, Type_Str (Tmp .. End_Of_Name - 1),
            Record_Field_Name
              (Lang, Entity, Type_Str (Index + 1 .. End_Of_Name - 1)),
            Tmp,
            Field_Value);
         Set_Value (R.all, Field_Value, Field);
         Index := Save + 1;
         Field := Field + 1;
      end loop;
   end Parse_Record_Type;

   -----------------------
   -- Parse_Array_Value --
   -----------------------

   procedure Parse_Array_Value
     (Lang     : access Gdb_C_Language;
      Type_Str : String;
      Index    : in out Natural;
      Result   : in out Array_Type_Access)
   is
      Dim     : Natural := 0;            --  current dimension
      Current_Index : Long_Integer := 0; --  Current index in the parsed array

      procedure Parse_Item;
      --  Parse the value of a single item, and add it to the contents of
      --  Result.

      ----------------
      -- Parse_Item --
      ----------------

      procedure Parse_Item is
         Tmp        : Generic_Type_Access;
         Repeat_Num : Integer;
      begin
         --  Parse the next item
         Tmp := Get_Value (Result.all, Current_Index);
         if Tmp = null then
            Tmp := Clone (Get_Item_Type (Result.all).all);
         end if;
         Internal_Parse_Value (Lang, Type_Str, Index, Tmp, Repeat_Num,
                               Parent => Generic_Type_Access (Result));
         Set_Value (Item       => Result.all,
                    Elem_Value => Tmp,
                    Elem_Index => Current_Index,
                    Repeat_Num => Repeat_Num);
         Current_Index := Current_Index + Long_Integer (Repeat_Num);
      end Parse_Item;

   begin
      loop
         case Type_Str (Index) is
            when '}' =>
               Dim := Dim - 1;
               Index := Index + 1;

            when '{' =>
               --  A parenthesis is either the start of a sub-array (for
               --  other dimensions, or one of the items in case it is a
               --  record or an array. The distinction can be made by
               --  looking at the current dimension being parsed.

               if Dim = Num_Dimensions (Result.all) then
                  Parse_Item;
               else
                  Dim := Dim + 1;
                  Index := Index + 1;
               end if;

            when ',' | ' ' =>
               Index := Index + 1;

            when others =>
               Parse_Item;

               --  Since access types can be followed by junk
               --  ("{0x804845c <foo>, 0x804845c <foo>}"), skip everything
               --  till the next character we know about.
               while Index <= Type_Str'Last
                 and then Type_Str (Index) /= ','
                 and then Type_Str (Index) /= '{'
                 and then Type_Str (Index) /= '}'
               loop
                  Index := Index + 1;
               end loop;

         end case;
         exit when Dim = 0;
      end loop;

      --  Shrink the table of values.
      Shrink_Values (Result.all);
   end Parse_Array_Value;

   -----------------
   -- Thread_List --
   -----------------

   function Thread_List (Lang : access Gdb_C_Language) return String is
   begin
      --  ??? Unsupported, should we raise an exception ?
      return "";
   end Thread_List;

   -------------------
   -- Thread_Switch --
   -------------------

   function Thread_Switch
     (Lang   : access Gdb_C_Language;
      Thread : Natural) return String is
   begin
      --  ??? Unsupported, should we raise an exception ?
      return "";
   end Thread_Switch;

   -----------------------
   -- Parse_Thread_List --
   -----------------------

   function Parse_Thread_List
     (Lang   : access Gdb_C_Language;
      Output : String) return Thread_Information_Array
   is
      Result      : Thread_Information_Array (1 .. 0);
   begin
      --  ??? Unsupported, should we raise an exception ?
      return Result;
   end Parse_Thread_List;

   --------------------------
   -- Get_Language_Context --
   --------------------------

   function Get_Language_Context (Lang : access Gdb_C_Language)
                                 return Language_Context
   is
   begin
      return (Record_Field_Length => Record_Field'Length,
              Record_Start        => Record_Start,
              Record_End          => Record_End,
              Array_Start         => Array_Start,
              Array_End           => Array_End,
              Record_Field        => Record_Field);
   end Get_Language_Context;


end Debugger.Gdb.C;

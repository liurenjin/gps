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

with Generic_Values; use Generic_Values;

package Language is

   type Language_Root is abstract tagged private;
   type Language_Access is access all Language_Root'Class;

   Unexpected_Type : exception;

   procedure Parse_Type
     (Lang     : Language_Root;
      Type_Str : String;
      Entity   : String;
      Index    : in out Natural;
      Result   : out Generic_Type_Access) is abstract;
   --  Parse the type of Entity.
   --  Type_Str should contain the type as returned by the debugger.
   --  Entity is used to get the type of the fields or array items.

   procedure Parse_Value
     (Lang       : Language_Root;
      Type_Str   : String;
      Index      : in out Natural;
      Result     : in out Generic_Values.Generic_Type_Access;
      Repeat_Num : out Positive) is abstract;
   --  Parse the value of an entity, for the Ada language.
   --  Type_Str should contain the value, as returned by the debugger itself.
   --  Repeat_Num is the number of times the item is repeated in the output.

   procedure Parse_Array_Type
     (Lang      : Language_Root;
      Type_Str  : String;
      Entity    : String;
      Index     : in out Natural;
      Result    : out Generic_Type_Access) is abstract;
   --  Parse the description of an array type.
   --  Index should point at the opening character of the array in Type_Str
   --  (ie "array " in gdb).

   procedure Parse_Record_Type
     (Lang      : Language_Root;
      Type_Str  : String;
      Entity    : String;
      Index     : in out Natural;
      Result    : out Generic_Type_Access;
      End_On    : String) is abstract;
   --  Parse the type describing a record.
   --  Index should pointer after the initial "record ", and the record is
   --  assumed to end on a string like End_On.
   --  This function is also used to parse the variant part of a record.

   function Is_Simple_Type
     (Lang : Language_Root; Str : String) return Boolean is abstract;
   --  Return True if Str is a simple type, like integer, ...

   procedure Parse_Array_Value
     (Lang     : Language_Root;
      Type_Str : String;
      Index    : in out Natural;
      Result   : in out Array_Type_Access) is abstract;
   --  Parse the value of an array.

private
   type Language_Root is abstract tagged null record;
end Language;

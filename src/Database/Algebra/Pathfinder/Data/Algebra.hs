{-# LANGUAGE FlexibleInstances    #-}
{-# LANGUAGE GADTs                #-}
{-# LANGUAGE RankNTypes           #-}
{-# LANGUAGE TypeSynonymInstances #-}
--new, required for JSON
{-# LANGUAGE DeriveGeneric #-}
{-|
The Algebra module provides the internal datatypes used for
constructing algebaric plans. It is not recommended to use these
datatypes directly instead it is adviced the to use the functions
provided by the module Database.Algebra.Pathfinder.Algebra.Create
-}
module Database.Algebra.Pathfinder.Data.Algebra where

import Numeric                     (showFFloat)
import Text.Printf

import Database.Algebra.Aux
import Database.Algebra.Dag        (Operator, opChildren, replaceOpChild)
import Database.Algebra.Dag.Common

-- required for JSON
import GHC.Generics (Generic)

-- | The column data type is used to represent the table structure while
--  compiling ferry core into an PFAlgebraic plan
--  The col column contains the column number and the type of its contents
--  The NCol column is used to group columns that together form an element of a record
-- , its string argument is used to represent the field name.
data Column where
    Col :: Int -> ATy -> Column
    NCol :: String -> Columns -> Column
  deriving (Show, Generic)

-- | One table can have multiple columns
type Columns = [Column]

-- | Sorting rows in a direction
data SortDir = Asc
             | Desc
    deriving (Eq, Ord, Generic, Read)

data AggrType = Avg AttrName
              | Max AttrName
              | Min AttrName
              | Sum AttrName
              | Count
              | All AttrName
              | Prod AttrName
              | Dist AttrName
    deriving (Eq, Ord, Generic)

instance Show AggrType where
    show (Avg c)  = printf "avg(%s)" c
    show (Max c)  = printf "max(%s)" c
    show (Min c)  = printf "min(%s)" c
    show (Sum c)  = printf "sum(%s)" c
    show Count    = "count"
    show (All c)  = printf "all(%s)" c
    show (Prod c) = printf "prod(%s)" c
    show (Dist c) = printf "dist(%s)" c

-- | The show instance results in values that are accepted in the xml plan.
instance Show SortDir where
    show Asc  = "ascending"
    show Desc = "descending"

-- | PFAlgebraic types
--  At this level we do not have any structural types anymore
--  those are represented by columns. ASur is used for surrogate
--  values that occur for nested lists.
data ATy where
    AInt :: ATy
    AStr :: ATy
    ABool :: ATy
    ADec :: ATy
    ADouble :: ATy
    ANat :: ATy
    ASur :: ATy
    deriving (Eq, Ord, Generic)

-- | Show the PFAlgebraic types in a way that is compatible with
--  the xml plan.
instance Show ATy where
  show AInt     = "int"
  show AStr     = "str"
  show ABool    = "bool"
  show ADec     = "dec"
  show ADouble  = "dbl"
  show ANat     = "nat"
  show ASur     = "nat"

-- | Wrapper around values that can occur in an PFAlgebraic plan
data AVal where
  VInt    :: Integer -> AVal
  VStr    :: String -> AVal
  VBool   :: Bool -> AVal
  VDouble :: Double -> AVal
  VDec    :: Float -> AVal
  VNat    :: Integer -> AVal
    deriving (Eq, Ord, Generic)

-- | Show the values in the way compatible with the xml plan.
instance Show AVal where
  show (VInt x)     = show x
  show (VStr x)     = x
  show (VBool True)  = "true"
  show (VBool False) = "false"
  show (VDouble x)     =  show x
  show (VDec x)     = showFFloat (Just 2) x ""
  show (VNat x)     = show x

-- | Pair of a type and a value
type ATyVal = (ATy, AVal)

-- | Attribute name or column name
type AttrName            = String

-- | Result attribute name, used as type synonym where the name for a result column of a computation is needed
type ResAttrName         = AttrName

-- | Sort attribute name, used as type synonym where a column for sorting is needed
type SortAttrName        = AttrName

-- | Partition attribute name, used as a synonym where the name for the partitioning column is expected by the rownum operator
type PartAttrName        = AttrName

-- | New attribute name, used to represent the new column name when renaming columns
type NewAttrName         = AttrName

-- | Old attribute name, used to represent the old column name when renaming columns
type OldAttrName         = AttrName

-- | Selection attribute name, used to represent the column containing the selection boolean
type SelAttrName         = AttrName

-- | Left attribute name, used to represent the left argument when applying binary operators
type LeftAttrName        = AttrName

-- | Right attribute name, used to represent the right argument when applying binary operators
type RightAttrName       = AttrName
--
-- | Name of a database table
type TableName           = String

-- | List of table attribute information consisting of (column name, new column name, type of column)
type TableAttrInf        = [(AttrName, AttrName, ATy)]

-- | Key of a database table, a key consists of multiple column names
newtype Key = Key [AttrName] deriving (Eq, Ord, Show, Generic)

-- | Sort information, a list (ordered in sorting priority), of pair of columns and their sort direction--
type SortInf              = [(SortAttrName, SortDir)]

-- | New and old attribute name
type ProjPair             = (NewAttrName, OldAttrName)

-- | Projection information, a list of new attribute names, and their old names.
type ProjInf              = [ProjPair]

-- | A tuple is a list of values
type Tuple = [AVal]

-- | Schema information, represents a table structure, the first element of the
-- tuple is the column name the second its type.
type SchemaInfos = [(AttrName, ATy)]

type SemInfRowNum  = (ResAttrName, SortInf, Maybe PartAttrName)

-- | Information that specifies how to perform the rank operation.  its first
--  element is the column where the output of the operation is inserted the
--  second element represents the sorting criteria that determine the ranking.
type SemInfRank    = (ResAttrName,  SortInf)

-- | Information that specifies a projection
type SemInfProj    = ProjInf


-- | Information that specifies which column contains the conditional
type SemInfSel     = SelAttrName

-- | Information that specifies how to select element at a certain position
type SemInfPosSel  = (Int, SortInf, Maybe PartAttrName)


-- | Information on how to perform an eq-join. The first element represents the
-- column from the first table that has to be equal to the column in the second
-- table represented by the second element in the pair.
type SemInfEqJoin  = (LeftAttrName,RightAttrName)

-- | Information on how to perform a theta-join. The first element represents
-- the column from the first table that has to relate to the column in the
-- second table represnted by the second element in tuple. The third element
-- represents the type of relation.
type SemInfThetaJoin = [(LeftAttrName, RightAttrName, JoinRel)]

-- | Comparison operators which can be used for ThetaJoins.
data JoinRel = EqJ -- equal
             | GtJ -- greater than
             | GeJ -- greater equal
             | LtJ -- less than
             | LeJ -- less equal
             | NeJ -- not equal
             deriving (Eq, Ord, Generic)
             
instance Show JoinRel where
  show EqJ = "eq"
  show GtJ = "gt"
  show GeJ = "ge"
  show LtJ = "lt"
  show LeJ = "le"
  show NeJ = "ne"

-- | Information what to put in a literate table
type SemInfLitTable = [Tuple]

-- | Information for accessing a database table
type SemInfTableRef = (TableName, TableAttrInf, [Key])

-- | Information what column, the first element, to attach to a table and what its content would be, the second element.
type SemInfAttach   = (ResAttrName, ATyVal)

type SemInfCast     = (ResAttrName, AttrName, ATy)

-- | Information on how to perform a binary operation
-- The first element is the function that is to be performed
-- The second element the column name for its result
-- The third element is the left argument for the operator
-- The fourth element is the right argument for the operator
type SemBinOp = (Fun, ResAttrName, LeftAttrName, RightAttrName) -- FIXME
     
-- | Binary functions, arithmetic and logical operators.
data Fun1to1 = Plus
             | Minus
             | Times
             | Div
             | Modulo
             | Contains
             | SimilarTo
             | Like
             | Concat
             deriving (Eq, Ord, Generic)
     
instance Show Fun1to1 where
  show Minus     = "subtract"
  show Plus      = "add"
  show Times     = "multiply"
  show Div       = "divide"
  show Modulo    = "modulo"
  show Contains  = "fn:contains"
  show Concat    = "fn:concat"
  show SimilarTo = "fn:similar_to"
  show Like      = "fn:like"
         
data RelFun = Gt
            | Lt
            | Eq
            | And
            | Or
            deriving (Eq, Ord, Generic)
            
instance Show RelFun where
  show Gt  = "gt"
  show Lt  = "lt"
  show Eq  = "eq"
  show And = "and"
  show Or  = "or"
            
data Fun = Fun1to1 Fun1to1 | RelFun RelFun deriving (Eq, Ord, Generic)

instance Show Fun where
  show (Fun1to1 f) = show f
  show (RelFun r)  = show r

type SemUnOp = (ResAttrName, AttrName)

type SemInfAggr  = ([(AggrType, ResAttrName)], Maybe PartAttrName)

data NullOp = LitTable SemInfLitTable SchemaInfos
            | EmptyTable SchemaInfos
            | TableRef SemInfTableRef
            deriving (Ord, Eq, Show, Generic)

data UnOp = RowNum SemInfRowNum
          | RowRank SemInfRank
          | Rank SemInfRank
          | Proj SemInfProj
          | Sel SemInfSel
          | PosSel SemInfPosSel
          | Distinct ()
          | Attach SemInfAttach
          | FunBinOp SemBinOp
          | Cast SemInfCast
          | FunBoolNot SemUnOp
          | Aggr SemInfAggr
          | Dummy String
          deriving (Ord, Eq, Show, Generic)

data BinOp = Cross ()
           | EqJoin SemInfEqJoin
           | ThetaJoin SemInfThetaJoin
           | DisjUnion ()
           | Difference ()
           deriving (Ord, Eq, Show, Generic)

type PFAlgebra = Algebra () BinOp UnOp NullOp AlgNode

replaceChild :: forall t b u n c. Eq c => c -> c -> Algebra t b u n c -> Algebra t b u n c
replaceChild o n (TerOp op c1 c2 c3) = TerOp op (replace o n c1) (replace o n c2) (replace o n c3)
replaceChild o n (BinOp op c1 c2) = BinOp op (replace o n c1) (replace o n c2)
replaceChild o n (UnOp op c) = UnOp op (replace o n c)
replaceChild _ _ (NullaryOp op) = NullaryOp op

instance Operator PFAlgebra where
    opChildren (TerOp _ c1 c2 c3) = [c1, c2, c3]
    opChildren (BinOp _ c1 c2) = [c1, c2]
    opChildren (UnOp _ c) = [c]
    opChildren (NullaryOp _) = []

    replaceOpChild op old new = replaceChild old new op

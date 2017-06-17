(*
    Monadic contextual classification Mathematica package
    Copyright (C) 2017  Anton Antonov

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.

    Written by Anton Antonov,
    antononcube @ gmail.com,
    Windermere, Florida, USA.
*)

(*
    Mathematica is (C) Copyright 1988-2017 Wolfram Research, Inc.

    Protected by copyright law and international treaties.

    Unauthorized reproduction or distribution subject to severe civil
    and criminal penalties.

    Mathematica is a registered trademark of Wolfram Research, Inc.
*)

(* :Title: MonadicContextualClassification *)
(* :Context: MonadicContextualClassification` *)
(* :Author: Anton Antonov *)
(* :Date: 2017-06-05 *)

(* :Package Version: 0.5 *)
(* :Mathematica Version: *)
(* :Copyright: (c) 2017 Anton Antonov *)
(* :Keywords: *)
(* :Discussion:


    ## Introduction

    This package provides functions for classification with classifiers with contexts.
    That is achieved by extending the functions of a State monad generated by the package
    "StateMonadCodeGenerator.m", [1], with functions specific to classification work flow.

    Here is an example of a pipeline created with the functions in the package:

       res =
         ClCon[ds, <||>] ⟹
           ClConSplitData[0.75] ⟹
           ClConMakeClassifier["NearestNeighbors"] ⟹
           ClConEchoFunctionContext[ClassifierInformation[#["classifier"]] &] ⟹
           ClConClassifierMeasurements[{"Accuracy", "Precision", "Recall"}] ⟹
           ClConEchoValue ⟹
           (If[#1["Accuracy"] > 0.7, None, ClCon[#1, #2]] &) ⟹
           ClConMakeClassifier["RandomForest"] ⟹
           ClConEchoFunctionContext[ClassifierInformation[#["classifier"]] &] ⟹
           ClConClassifierMeasurements[{"Accuracy", "Precision", "Recall"}] ⟹
           ClConEchoValue;


    ## Contexts

    The classifier contexts are Association objects. The pipeline values can have the form:

        ClCon[ val, context:(_String|_Association) ]

    see the explanations in [1] for more details.

    Some of the specific functions set or retrieve values from contexts for the keys:
    "trainData", "testData", "classifier".


    ## Error messages

    The error messages are print-outs with `Echo`. They can be easily changed to use `Message` instead.
    (`Echo` is used since it fits the monadic pipeline "culture.")


    ## Examples

    ### Data

    Assume we have the Titanic data as dataset:

       dataName = "Titanic";
       ds = Dataset[Flatten@*List @@@ ExampleData[{"MachineLearning", dataName}, "Data"]];
       varNames = Flatten[List @@ ExampleData[{"MachineLearning", dataName}, "VariableDescriptions"]];
       ds = ds[All, AssociationThread[varNames -> #] &];

    ### Complete usage example

    TBD...


    ### Complete usage example with string contexts

    TBD...


    ## References

    [1] Anton Antonov, StateMonadCodeGenerator.m, 2017, MathematicaForPrediction at GitHub.
        URL: https://github.com/antononcube/MathematicaForPrediction/blob/master/MonadicProgramming/StateMonadCodeGenerator.m


    ## End matters

    This file was created by Mathematica Plugin for IntelliJ IDEA.

    Anton Antonov
    Windermere, FL, USA
    2017-06-05

*)

(*
    TODO:
     1. Add examples explaned in detail.
     2. Make a true package.
     3. Add classifier ensemble handling.
     4. Give examples of tracking symbols.
*)

(*BeginPackage["MonadicContextualClassification`"]*)

(*ClConSplitData::usage = "ClConSplitData[fr_?NumberQ]";*)

(*ClConRecoverData::usage = "ClConRecoverData";*)

(*ClConMakeClassifier::usage = "ClConMakeClassifier[methodSpec_?MethodSpecQ]";*)

(*ClConClassifierMeasurements::usage = "ClConClassifierMeasurements[measures : (_String | {_String ..})]";*)

(*ClConAccuracyByVariableShuffling::usage = "ClConAccuracyByVariableShuffling[opts : OptionsPattern[]]";*)

(*Begin["`Private`"]*)

If[Length[DownValues[StateMonadCodeGenerator`GenerateStateMonadCode]] == 0,
  Import["https://raw.githubusercontent.com/antononcube/MathematicaForPrediction/master/MonadicProgramming/StateMonadCodeGenerator.m"]
];

If[Length[DownValues[ClassifierEnsembles`EnsembleClassifierMeasurements]] == 0,
  Import["https://raw.githubusercontent.com/antononcube/MathematicaForPrediction/master/ClassifierEnsembles.m"]
];

If[Length[DownValues[VariableImportanceByClassifiers`AccuracyByVariableShuffling]] == 0,
  Import["https://raw.githubusercontent.com/antononcube/MathematicaForPrediction/master/VariableImportanceByClassifiers.m"]
];

(*Needs["StateMonadCodeGenerator`"]*)
(*Needs["VariableImportanceByClassifiers`"]*)

(* The definitions are made to have a prefix "ClCon" . *)

(**************************************************************)
(* Generation                                                 *)
(**************************************************************)

(* Generate base functions of ClCon monad (ClassifierWithContext) *)

GenerateStateMonadCode["ClCon"]

(**************************************************************)
(* Infix operators                                            *)
(**************************************************************)

(* This should be already done by GenerateStateMonadCode. *)
(*DoubleLongRightArrow[x_?ClConUnitQ, f_] := ClConBind[x, f];*)

(**************************************************************)
(* General functions                                          *)
(**************************************************************)

Clear[ClConToNormalClassifierData]
ClConToNormalClassifierData[td_Dataset] :=
    Thread[#[[All, 1 ;; -2]] -> #[[All, -1]]] &@ Normal[DeleteMissing[td, 1, 2][All, Values]];


(**************************************************************)
(* Monad specific functions                                   *)
(**************************************************************)

ClConSplitData[_][None] := None
ClConSplitData[fr_?NumberQ][xs_, context_Association] :=
    ClCon[AssociationThread[{"trainData", "testData"} ->
        TakeDrop[RandomSample[xs], Floor[fr*Length[xs]]]], context] /; 0 < fr <= 1;

ClConRecoverData[None] := None
ClConRecoverData[xs_, context_Association] :=
    Block[{},
      Which[
        MatchQ[xs, _Association] && KeyExistsQ[xs, "trainData"] && KeyExistsQ[xs, "testData"],
        ClCon[Join[xs["trainData"], xs["testData"]], context],

        KeyExistsQ[context, "trainData"] && KeyExistsQ[context, "testData"],
        ClCon[Join[context["trainData"], context["testData"]], context],

        True,
        Echo["Cannot recover data.","ClConRecoverData:"];
        None
      ]
    ];


(************************************************************)
(* ClConMakeClassifier                                      *)
(************************************************************)

ClConMethodQ[x_] := StringQ[x]; (* And check is it known by Classifiy. *)

ClConMethodListQ[x_] := MatchQ[ x, {_?ClConMethodQ..} ];

ClConResamplingMethodQ[x_] := MatchQ[ x, (_String | {_String, _?NumberQ} | {_String, _?NumberQ, _Integer}) ];

(* Note that is includes MethodListQ. *)
ClConResamplingMethodListQ[x_] := MatchQ[ x, { _?ClConResamplingMethodQ .. } ];

ClConMethodSpecQ[x_] := ClConMethodQ[x] || ClConResamplingMethodQ[x] || ClConResamplingMethodListQ[x];

ClConClassifierQ[ cl_ ] :=
    MatchQ[ cl, _ClassifierFunction] ||
        If[Length[DownValues[ClassifierEnsembles`EnsembleClassifierMeasurements]] > 0,
          MatchQ[ cl, Association[(_ -> _ClassifierFunction) ..] ]
        ];

ClConMakeClassifier[_][None] := None;
ClConMakeClassifier[methodSpec_?ClConMethodSpecQ][xs_, context_] :=
    Block[{cf, dataAssoc, newContext},

      Which[
        MatchQ[xs, _Association] && KeyExistsQ[xs, "trainData"] && KeyExistsQ[xs, "testData"],
        dataAssoc = xs; newContext = Join[context, xs],

        KeyExistsQ[context, "trainData"] && KeyExistsQ[context, "testData"],
        dataAssoc = context; newContext = <||>,

        True,
        Echo["Split the data first. (No changes in argument and context were made.)", "ClConMakeClassifier:"];
        Return[ClCon[xs, context]]
      ];

      Which[
        ClConMethodQ[methodSpec],
        cf = Classify[ClConToNormalClassifierData[dataAssoc@"trainData"], Method -> methodSpec],

        ClConMethodListQ[methodSpec],
        cf = EnsembleClassifier[ methodSpec, ClConToNormalClassifierData[dataAssoc@"trainData"] ],

        ClConResamplingMethodQ[methodSpec],
        cf = ResamplingEnsembleClassifier[ {methodSpec}, ClConToNormalClassifierData[dataAssoc@"trainData"] ],

        ClConResamplingMethodListQ[methodSpec],
        cf = ResamplingEnsembleClassifier[ methodSpec, ClConToNormalClassifierData[dataAssoc@"trainData"] ],

        True,
        Echo["Uknown classifier specification.", "ClConMakeClassifier:"];
        cf = None;
      ];

      If[ ! ClConClassifierQ[cf],
        Echo["Classifier making failure.", "ClConMakeClassifier:"];
        None,
        (* ELSE *)
        ClCon[cf, Join[context, newContext, <|"classifier" -> cf|>]]
      ]
    ];


(************************************************************)
(* ClConClassifierMeasurements                              *)
(************************************************************)

ClConClassifierMeasurements[_][None] := None;
ClConClassifierMeasurements[measures : (_String | {_String ..})][xs_, context_] :=
    Block[{cm},
      Which[
        KeyExistsQ[context, "classifier"] && MatchQ[ context["classifier"], _ClassifierFunction],
        cm = ClassifierMeasurements[context["classifier"], ClConToNormalClassifierData[context@"testData"]];
        ClCon[AssociationThread[measures -> cm /@ Flatten[{measures}]], context],

        KeyExistsQ[context, "classifier"],
        cm = EnsembleClassifierMeasurements[ context["classifier"], ClConToNormalClassifierData[context@"testData"], Flatten[{measures}]];
        ClCon[AssociationThread[measures -> cm], context],

        True,
        Echo["Make a classifier first.", "ClConClassifierMeasurements:"];
        None
      ]
    ];


(************************************************************)
(* ClConAccuracyByVariableShuffling                         *)
(************************************************************)

ClConAccuracyByVariableShuffling[][xs_, context_] :=
    ClConAccuracyByVariableShuffling["FScoreLabels" -> None][xs, context];
ClConAccuracyByVariableShuffling[opts : OptionsPattern[]][xs_, context_] :=
    Block[{fsClasses = FilterRules[{opts}, "FScoreLabels"]},

      If[Length[fsClasses] == 0 || fsClasses === Automatic, fsClasses = None];

      ClCon[AccuracyByVariableShuffling[
        context["classifier"],
        ClConToNormalClassifierData[context["testData"]],
        Most@Keys[Normal@context["testData"][[1]]],
        fsClasses],
        context]
    ];

(*End[]  *`Private` *)

(*EndPackage[]*)

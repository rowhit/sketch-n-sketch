find regex s =
    case extractFirstIn ("(" + regex + ")([\\s\\S]*)") s of
      Nothing -> []
      Just matchremaining ->
        case (LensLess.List.split (len matchremaining - 1) matchremaining) of
          [init, [last]] ->
            init::find regex last

Regex = { Regex | find = find }

variables = [("document", "web $page"),("page", "page")]

variablesDict = Dict.fromList variables

replaceVariables variablesDict string =
  Regex.replace "\\$(?!_)(\\w+)" (\m -> 
    let key = nth m.group 1 in
    case Dict.get key variablesDict of
      Nothing -> m.match
      Just definition -> replaceVariables (remove key variablesDict) definition
  ) string

content = """<h1>Programmable $document</h1>
This $document is special. If you add a $ just before a word A, the $ disappear but now everywhere you write $_A, it clones the word.
This means that if you edit such a word at one place, it will change at another place. '$document' was obtained from such a word, you can change it.<br><br>
Additionally, to write $_x literally, just write $__x. You can also define shorter names by writing $_x=[longword] instead of $_[longword].
""" |>
  replaceVariables variablesDict |>
  Regex.replace "(\\$)_(\\w+)" (\m ->
    nth m.group 1 + "<span></span>" + nth m.group 2) |>
  (\x ->
    { apply (x, variables) = freeze x
      update {input = (x, variables), output} =
        Regex.find "\\$(?!_)(\\w+)(?:=(\\w+))?" output |>
        List.foldl (\(_::name::definition::_) variables ->
          if Dict.member name variablesDict  then variables
          else variables ++ [(name, if definition == "" then name else definition)]
        ) variables |> \newVariables ->
          let newOutput = Regex.replace "\\$(?!_)(\\w+)(?:=(\\w+))?" (\m -> 
            let [_, name, _] = m.group in
             if Dict.member name variablesDict then m.match else "$" + name
          ) output in
          { values = [(newOutput, newVariables)] }
    }.apply (x, variables)
  )

Html.div_ [["margin", "20px"], ["cursor", "text"]] [] [
  Html.span [] [] <|
  html content
]
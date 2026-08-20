# -*- coding: utf-8 -*-
from pathlib import Path
OUT = Path(r"c:\Users\arang\OneDrive\Documentos\GitHub\AppParlando\lib\data\practice\practice_bank.dart")

def esc(s):
    return s.replace("\\", "\\\\").replace("'", "\\'")

def ex(eid, level, cat, typ, instruction, prompt, options, answer, explanation=""):
    opts = ", ".join(f"'{esc(o)}'" for o in options)
    exp = f", explanation: '{esc(explanation)}'" if explanation else ""
    return (
        f"  PracticeExercise(id: '{eid}', level: '{level}', category: PracticeCategory.{cat}, "
        f"type: ExerciseType.{typ}, instruction: '{esc(instruction)}', prompt: '{esc(prompt)}', "
        f"options: [{opts}], answer: '{esc(answer)}'{exp}),"
    )

items = []
type_map = {"mc": "multipleChoice", "fill": "fillBlank", "tr": "translate"}

# Import data from a compact approach - execute the big generator from file
print("loading generator...")

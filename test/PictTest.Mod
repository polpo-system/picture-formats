MODULE PictTest;  (** PictTest.Open file width height: the picture file opens with that size *)
IMPORT Texts, Oberon, Pictures, out;  (* out: the standard output, for the tests of portia *)

PROCEDURE Open*;
VAR S: Texts.Scanner; name: ARRAY 64 OF CHAR; w, h: LONGINT; P: Pictures.Picture;
BEGIN
  Texts.OpenScanner(S, Oberon.Par.text, Oberon.Par.pos); Texts.Scan(S);
  IF (S.class # Texts.Name) & (S.class # Texts.String) THEN out.String("usage: PictTest.Open file width height"); out.Ln; RETURN END;
  COPY(S.s, name); Texts.Scan(S); w := S.i; Texts.Scan(S); h := S.i;
  NEW(P); Pictures.Open(P, name, TRUE);
  out.String("PictTest: "); out.String(name); out.Char(" "); out.Int(P.width, 0); out.String(" x "); out.Int(P.height, 0);
  IF (P.width = w) & (P.height = h) THEN out.String(" ok") ELSE out.String(" wrong") END;
  out.Ln
END Open;

END PictTest.

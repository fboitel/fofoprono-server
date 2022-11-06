-- Your SQL goes here
CREATE TABLE users (
  id SERIAL PRIMARY KEY,

  name VARCHAR(20) NOT NULL,
  mail VARCHAR(100) NOT NULL,
  password VARCHAR(20) NOT NULL,

  score INT NOT NULL DEFAULT 0,
  results_good INT NOT NULL DEFAULT 0,
  results_perfect INT NOT NULL DEFAULT 0,

  active BOOLEAN NOT NULL DEFAULT false,

  CONSTRAINT user_mail UNIQUE (mail)
);

CREATE TYPE STAGE AS ENUM ('group', 'sixteen', 'quarter', 'semi', 'final');

CREATE TABLE games (
  id SERIAL PRIMARY KEY,
  time TIMESTAMP NOT NULL,
  stage STAGE NOT NULL,

  team_home VARCHAR(20) NOT NULL,
  team_away VARCHAR(20) NOT NULL,

  score_home INTEGER,
  score_away INTEGER,

  odds_home FLOAT NOT NULL,
  odds_away FLOAT NOT NULL,
  odds_draw FLOAT NOT NULL
);

CREATE TYPE RESULT AS ENUM ('exact', 'correct', 'wrong');

CREATE TABLE pronos (
  PRIMARY KEY(user_id, game_id),
  user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  game_id INTEGER NOT NULL REFERENCES games(id),

  prediction_home INTEGER NOT NULL CHECK (prediction_home >= 0),
  prediction_away INTEGER NOT NULL CHECK (prediction_away >= 0),

  result RESULT
);

CREATE TABLE hashes (
  id TEXT PRIMARY KEY DEFAULT md5(random()::text),
  user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE
);

-- Create a trigger to compute the score of a user when a match result is updated
CREATE OR REPLACE FUNCTION update_result() RETURNS TRIGGER AS $$
BEGIN
  UPDATE pronos SET result = (
    SELECT
      CASE
        WHEN games.score_home IS NULL OR games.score_away IS NULL then NULL
        WHEN pronos.prediction_home = games.score_home AND pronos.prediction_away = games.score_away THEN 'exact'::RESULT
        WHEN pronos.prediction_home > pronos.prediction_away AND games.score_home > games.score_away THEN 'correct'::RESULT
        WHEN pronos.prediction_home < pronos.prediction_away AND games.score_home < games.score_away THEN 'correct'::RESULT
        WHEN pronos.prediction_home = pronos.prediction_away AND games.score_home = games.score_away THEN 'correct'::RESULT
        ELSE 'wrong'::RESULT
      END
    FROM games WHERE pronos.game_id = games.id
  );

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_result
  AFTER UPDATE OF score_home, score_away ON games
  FOR EACH ROW EXECUTE PROCEDURE update_result();

CREATE OR REPLACE FUNCTION update_score() RETURNS TRIGGER AS $$
BEGIN
  UPDATE users SET score = (
    SELECT COALESCE(SUM(
      CASE
        WHEN pronos.result = 'exact' THEN 3
        WHEN pronos.result = 'correct' THEN 1
        ELSE 0
      END
    ), 0) FROM pronos WHERE pronos.user_id = users.id
  );

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_score
  AFTER UPDATE OF result ON pronos
  FOR EACH ROW EXECUTE PROCEDURE update_score();

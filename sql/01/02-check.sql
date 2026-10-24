\set ON_ERROR_STOP on
DO $$
BEGIN
  IF (SELECT count(*) FROM books) <> 1000000 OR
     (SELECT count(*) FROM reading_records) <> 2000000 THEN
    RAISE EXCEPTION '第1章の初期件数と一致しません';
  END IF;
  IF (SELECT count(DISTINCT finished_at) FROM reading_records) <> 2000000 OR
     EXISTS (SELECT 1 FROM reading_records
             WHERE finished_at < timestamp '2026-08-24' OR finished_at >= timestamp '2026-09-21') OR
     (SELECT count(*) FROM (
        SELECT date_trunc('week', finished_at) FROM reading_records
        GROUP BY 1 HAVING count(*) = 500000
      ) AS weeks) <> 4 THEN
    RAISE EXCEPTION '日時が重複しているか、4週間それぞれ50万件になっていません';
  END IF;
  IF (SELECT count(*) FROM books WHERE title = '実験用の本 42' AND id = 42) <> 1 THEN
    RAISE EXCEPTION '検索対象が初期データと一致しません';
  END IF;
  IF EXISTS (SELECT 1 FROM reading_records r LEFT JOIN books b ON b.id = r.book_id WHERE b.id IS NULL) THEN
    RAISE EXCEPTION '対応する本がない読了記録があります';
  END IF;
  IF (SELECT count(*) FROM pg_indexes WHERE schemaname = 'public' AND tablename = 'books') <> 1 THEN
    RAISE EXCEPTION '第1章ではbooksの索引は主キーの1本だけにします';
  END IF;
END $$;
\echo 第1章の初期データを確認しました。

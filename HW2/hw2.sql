-- =====================================================================
--  SQL Homework №2 Васильева Анна 
-- =====================================================================
SET search_path = hh_school, public;


-- =====================================================================
-- ЗАДАНИЕ 1. Аудит качества данных
-- =====================================================================

-- 1.1. Проверки. Одна строка = один тип проверки
SELECT
    'C01: Звонки, которые не привязаны к отклику (нет response_id)' AS problem,
    COUNT(*) AS rows_cnt,
    STRING_AGG(call_id::text, ', ' ORDER BY call_id) AS record_ids
FROM calls
WHERE response_id IS NULL
UNION ALL
SELECT
    'C02: У звонков без response_id отклик создан позже звонка',
    COUNT(*),
    STRING_AGG(c.call_id::text, ', ' ORDER BY c.call_id)
FROM calls AS c
JOIN responses AS r
    ON r.vacancy_id = c.vacancy_id
    AND r.resume_id = c.applicant_id
WHERE c.response_id IS NULL
  AND r.created_at > c.call_at
UNION ALL
SELECT
    'C03: В звонках данные не совпадают с данными отклика',
    COUNT(*),
    STRING_AGG(c.call_id::text, ', ' ORDER BY c.call_id)
FROM calls AS c
JOIN responses AS r
    ON r.response_id = c.response_id
JOIN vacancies AS v
    ON v.vacancy_id = r.vacancy_id
WHERE c.vacancy_id <> r.vacancy_id
   OR c.employer_id <> v.employer_id
   OR c.applicant_id <> r.resume_id
UNION ALL
SELECT
    'C04: В сообщениях данные не совпадают с данными отклика',
    COUNT(*),
    STRING_AGG(m.message_id::text, ', ' ORDER BY m.message_id)
FROM messages AS m
JOIN responses AS r
    ON r.response_id = m.response_id
JOIN vacancies AS v
    ON v.vacancy_id = r.vacancy_id
WHERE m.vacancy_id <> r.vacancy_id
   OR m.employer_id <> v.employer_id
   OR m.applicant_id <> r.resume_id
UNION ALL
SELECT
    'C05: Звонок раньше отклика',
    COUNT(*),
    STRING_AGG(c.call_id::text, ', ' ORDER BY c.call_id)
FROM calls AS c
JOIN responses AS r
    ON r.response_id = c.response_id
WHERE c.call_at < r.created_at
UNION ALL
SELECT
    'C06: Сообщение раньше отклика',
    COUNT(*),
    STRING_AGG(m.message_id::text, ', ' ORDER BY m.message_id)
FROM messages AS m
JOIN responses AS r
    ON r.response_id = m.response_id
WHERE m.sent_at < r.created_at
UNION ALL
SELECT
    'C07: Статус звонка и его длительность противоречат друг другу',
    COUNT(*),
    STRING_AGG(call_id::text, ', ' ORDER BY call_id)
FROM calls
WHERE (status = 'successful' AND call_duration IS NULL)
   OR (status <> 'successful' AND call_duration IS NOT NULL)
UNION ALL
SELECT
    'C08: Тег звонка не соответствует его статусу',
    COUNT(*),
    STRING_AGG(call_id::text, ', ' ORDER BY call_id)
FROM calls
WHERE NOT (
       (status = 'successful' AND 'connected' = ANY(call_tags))
    OR (status = 'unsuccessful' AND 'no_answer' = ANY(call_tags))
    OR (status = 'error' AND 'technical_error' = ANY(call_tags))
)
UNION ALL
SELECT
    'C09: Нет длительности звонка',
    COUNT(*),
    STRING_AGG(call_id::text, ', ' ORDER BY call_id)
FROM calls
WHERE call_duration IS NULL
UNION ALL
SELECT
    'C10: В метаданных сообщения не хватает ключейs',
    COUNT(*),
    STRING_AGG(message_id::text, ', ' ORDER BY message_id)
FROM messages
WHERE message_meta -> 'channel' IS NULL
   OR message_meta -> 'is_read' IS NULL
   OR message_meta -> 'attachments' IS NULL
ORDER BY problem;


-- 1.2. Длительность успешных звонков: среднее, медиана, p99, выбросы.
WITH successful_calls AS (         -- берем только успешные звонки, у которых есть длительность
    SELECT
        call_id,
        call_duration
    FROM calls
    WHERE status = 'successful'
      AND call_duration IS NOT NULL
),
duration_threshold AS (            -- Порог p99 (звонки дольше этого порога - редкие выбросы)
    SELECT
        PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY call_duration) AS p99_duration
    FROM successful_calls
)
SELECT
    COUNT(*) AS calls_cnt,
    ROUND(AVG(sc.call_duration), 2) AS avg_duration,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY sc.call_duration) AS median_duration,
    MAX(dt.p99_duration) AS p99_duration,
    COUNT(CASE WHEN sc.call_duration > dt.p99_duration THEN 1 END) AS calls_above_p99,
    ROUND(AVG(CASE WHEN sc.call_duration <= dt.p99_duration THEN sc.call_duration END), 2) AS avg_without_above_p99
FROM successful_calls AS sc
CROSS JOIN duration_threshold AS dt;  


-- 1.3. Какие именно звонки выше 99-го перцентиля.
SELECT
    call_id,
    call_duration
FROM calls
WHERE status = 'successful'
  AND call_duration > (
      SELECT PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY call_duration)
      FROM calls
      WHERE status = 'successful'
  )
ORDER BY call_duration DESC;

-- Вывод:
-- Найденные проблемы:
--  C01 - 8 звонков без response_id: call_id 700244, 700245, 700246, 700247, 700248, 700249, 700250, 700251.
--    Непонятно, к какому отклику относится звонок. Исключаем из анализа.
--  C02 - у всех этих 8 звонков отклик по вакансии и кандидату существует, но создан позже звонка, 
--    то есть это не коммуникация после отклика.
--  C09 - 70 звонков без длительности. Возможно, звонок не состоялся.
--     Влияет только длительность, попытка была, такие звонки оставляем.
-- Длительность 181 успешного звонка: среднее 467,28 с; медиана 438 с; p99 = 890,4 с; выше p99 - 2 звонка
--   (700199 = 899 с и 700159 = 892 с); среднее без них 462,49 с.
-- Значения выше p99 считаются допустимыми выбросами, а не ошибками: максимум 899 с (около 15 минут),
--   среднее без этих двух звонков отличается всего на 5 с.
--   Для типичной оценки беру медиану (438 с), так как она не зависит от крайних значений.


-- =====================================================================
-- ЗАДАНИЕ 2. Единый слой коммуникаций (первые 7 суток после отклика)
-- =====================================================================
WITH response_base AS (          -- Берем все отклики и добавляем к ним информацию о вакансии
    SELECT
        r.response_id,
        v.employer_id,
        v.professional_role,
        r.status AS response_status,
        r.created_at
    FROM responses AS r
    JOIN vacancies AS v
        ON v.vacancy_id = r.vacancy_id
),
messages_7d AS (                   -- Берем только сообщения от работодателя за первые 7 дней
    SELECT
        m.response_id,
        m.employer_id,
        m.message_id::text AS event_id,
        m.sent_at AS event_at,
        'message' AS event_type
    FROM messages AS m
    JOIN response_base AS rb
        ON rb.response_id = m.response_id
    WHERE m.sender_role = 'employer'
      AND m.sent_at >= rb.created_at
      AND m.sent_at < rb.created_at + INTERVAL '7 day'
),
calls_7d AS (                    -- Берем только звонки от работодателя за первые 7 дней
    SELECT
        c.response_id,
        c.employer_id,
        c.call_id::text AS event_id,
        c.call_at AS event_at,
        'call' AS event_type
    FROM calls AS c
    JOIN response_base AS rb       -- Отбрасываем 8 звонков без response_id
        ON rb.response_id = c.response_id
    WHERE c.caller_role = 'employer'
      AND c.call_at >= rb.created_at
      AND c.call_at < rb.created_at + INTERVAL '7 day'
),
events AS (                        -- 1 строка = 1 коммуникация (сообщение или звонок)
    SELECT response_id, employer_id, event_id, event_at, event_type
    FROM messages_7d
    UNION ALL                      
    SELECT response_id, employer_id, event_id, event_at, event_type
    FROM calls_7d
)
SELECT
    COUNT(*) AS events_total,
    COUNT(DISTINCT response_id) AS responses_with_communication,
    COUNT(CASE WHEN event_type = 'call' THEN 1 END) AS calls_cnt,
    COUNT(CASE WHEN event_type = 'message' THEN 1 END) AS messages_cnt
FROM events;

-- Вывод: событий 1096; откликов с коммуникацией 382; звонков 108; сообщений 988 (108 + 988 = 1096).


-- =====================================================================
-- ЗАДАНИЕ 3. Таймлайн коммуникаций и витрина отклика
-- =====================================================================

-- Шаг 1. Слой уровня события: 1 строка = 1 коммуникация (1096 строк), гранулярность не меняется.
-- Какое событие было по счету, какое было до него, а какое после.
WITH response_base AS (            -- 1 строка = 1 отклик (всего 628)
    SELECT
        r.response_id,
        v.employer_id,
        v.professional_role,
        r.status AS response_status,
        r.created_at
    FROM responses AS r
    JOIN vacancies AS v
        ON v.vacancy_id = r.vacancy_id
),
messages_7d AS (                   -- 1 строка = сообщение работодателя в первые 7 суток после отклика
    SELECT
        m.response_id,
        m.employer_id,
        m.message_id::text AS event_id,
        m.sent_at AS event_at,
        'message' AS event_type
    FROM messages AS m
    JOIN response_base AS rb
        ON rb.response_id = m.response_id
    WHERE m.sender_role = 'employer'
      AND m.sent_at >= rb.created_at
      AND m.sent_at < rb.created_at + INTERVAL '7 day'
),
calls_7d AS (                      -- 1 строка = звонок работодателя в первые 7 суток после отклика
    SELECT
        c.response_id,
        c.employer_id,
        c.call_id::text AS event_id,
        c.call_at AS event_at,
        'call' AS event_type
    FROM calls AS c
    JOIN response_base AS rb      
        ON rb.response_id = c.response_id
    WHERE c.caller_role = 'employer'
      AND c.call_at >= rb.created_at
      AND c.call_at < rb.created_at + INTERVAL '7 day'
),
events AS (                        -- 1 строка = 1 коммуникация (сообщение или звонок)
    SELECT response_id, employer_id, event_id, event_at, event_type
    FROM messages_7d
    UNION ALL                     
    SELECT response_id, employer_id, event_id, event_at, event_type
    FROM calls_7d
),
timeline AS (                      -- 1 строка = 1 коммуникация и её место в последовательности
    SELECT
        response_id,
        employer_id,
        event_id,
        event_at,
        event_type,
        ROW_NUMBER() OVER (
            PARTITION BY response_id
            ORDER BY event_at, event_type, event_id    
        ) AS event_number,
        LAG(event_at) OVER (
            PARTITION BY response_id
            ORDER BY event_at, event_type, event_id
        ) AS previous_event_at,
        LEAD(event_type) OVER (
            PARTITION BY response_id
            ORDER BY event_at, event_type, event_id
        ) AS next_event_type,
        COUNT(*) OVER (
            PARTITION BY response_id
            ORDER BY event_at, event_type, event_id
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS communications_so_far,
        FIRST_VALUE(event_type) OVER (
            PARTITION BY response_id
            ORDER BY event_at, event_type, event_id
        ) AS first_event_type,
        LAST_VALUE(event_type) OVER (
            PARTITION BY response_id
            ORDER BY event_at, event_type, event_id
            ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING  
        ) AS last_event_type
    FROM events
)
SELECT
    response_id,
    employer_id,
    event_id,
    event_at,
    event_type,
    event_number,
    previous_event_at,
    next_event_type,
    communications_so_far,
    first_event_type,
    last_event_type
FROM timeline
ORDER BY response_id, event_number;


-- Шаг 2. Витрина уровня отклика.
-- Схлопываем события так, чтобы 1 строка = 1 отклик. Считаем сводные метрики.
WITH response_base AS (            
    SELECT
        r.response_id,
        v.employer_id,
        v.professional_role,
        r.status AS response_status,
        r.created_at
    FROM responses AS r
    JOIN vacancies AS v
        ON v.vacancy_id = r.vacancy_id
),
messages_7d AS (                   -- 1 строка = сообщение работодателя в первые 7 суток после отклика
    SELECT
        m.response_id,
        m.employer_id,
        m.message_id::text AS event_id,
        m.sent_at AS event_at,
        'message' AS event_type
    FROM messages AS m
    JOIN response_base AS rb
        ON rb.response_id = m.response_id
    WHERE m.sender_role = 'employer'
      AND m.sent_at >= rb.created_at
      AND m.sent_at < rb.created_at + INTERVAL '7 day'
),
calls_7d AS (                      -- 1 строка = звонок работодателя в первые 7 суток после отклика
    SELECT
        c.response_id,
        c.employer_id,
        c.call_id::text AS event_id,
        c.call_at AS event_at,
        'call' AS event_type
    FROM calls AS c
    JOIN response_base AS rb       --  отбрасывает 8 звонков без response_id 
        ON rb.response_id = c.response_id
    WHERE c.caller_role = 'employer'
      AND c.call_at >= rb.created_at
      AND c.call_at < rb.created_at + INTERVAL '7 day'
),
events AS (                        -- 1 строка = 1 коммуникация (сообщение или звонок)
    SELECT response_id, employer_id, event_id, event_at, event_type
    FROM messages_7d
    UNION ALL                      
    SELECT response_id, employer_id, event_id, event_at, event_type
    FROM calls_7d
),
timeline AS (                      -- 1 строка = 1 коммуникация + её место в последовательности 
    SELECT
        response_id,
        employer_id,
        event_id,
        event_at,
        event_type,
        ROW_NUMBER() OVER (
            PARTITION BY response_id
            ORDER BY event_at, event_type, event_id     
        ) AS event_number,
        LAG(event_at) OVER (
            PARTITION BY response_id
            ORDER BY event_at, event_type, event_id
        ) AS previous_event_at,
        LEAD(event_type) OVER (
            PARTITION BY response_id
            ORDER BY event_at, event_type, event_id
        ) AS next_event_type,
        COUNT(*) OVER (
            PARTITION BY response_id
            ORDER BY event_at, event_type, event_id
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS communications_so_far,
        FIRST_VALUE(event_type) OVER (
            PARTITION BY response_id
            ORDER BY event_at, event_type, event_id
        ) AS first_event_type,
        LAST_VALUE(event_type) OVER (
            PARTITION BY response_id
            ORDER BY event_at, event_type, event_id
            ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING   
        ) AS last_event_type
    FROM events
),
response_mart AS (                 --  1 строка = 1 отклик (628)
    SELECT
        rb.response_id,
        rb.employer_id,
        rb.professional_role,
        rb.response_status,
        rb.created_at,
        COUNT(t.event_id) AS communications_count,                                 
        COUNT(CASE WHEN t.event_type = 'call' THEN 1 END) AS calls_count,
        COUNT(CASE WHEN t.event_type = 'message' THEN 1 END) AS messages_count,
        MIN(t.event_at) AS first_communication_at,
        MAX(t.first_event_type) AS first_communication_type,                        
        MAX(CASE WHEN t.event_number = 2 THEN t.event_type END) AS second_communication_type,
        MAX(t.last_event_type) AS last_communication_type,
        EXTRACT(EPOCH FROM MIN(t.event_at) - rb.created_at) / 3600.0 AS hours_to_first,
        EXTRACT(EPOCH FROM MAX(t.event_at - t.previous_event_at)) / 3600.0 AS max_gap_hours
    FROM response_base AS rb
    LEFT JOIN timeline AS t        
        ON t.response_id = rb.response_id
    GROUP BY
        rb.response_id,
        rb.employer_id,
        rb.professional_role,
        rb.response_status,
        rb.created_at
)
SELECT
    response_id,
    employer_id,
    professional_role,
    response_status,
    communications_count,
    calls_count,
    messages_count,
    first_communication_at,
    first_communication_type,
    second_communication_type,
    last_communication_type,
    ROUND(hours_to_first::numeric, 2) AS hours_to_first_communication,
    ROUND(max_gap_hours::numeric, 2) AS max_gap_hours
FROM response_mart
ORDER BY response_id;


-- Контрольные значения.
WITH response_base AS (            -- 1 строка = 1 отклик (всего 628)
    SELECT
        r.response_id,
        v.employer_id,
        v.professional_role,
        r.status AS response_status,
        r.created_at
    FROM responses AS r
    JOIN vacancies AS v
        ON v.vacancy_id = r.vacancy_id
),
messages_7d AS (                   -- 1 строка = сообщение работодателя в первые 7 суток после отклика
    SELECT
        m.response_id,
        m.employer_id,
        m.message_id::text AS event_id,
        m.sent_at AS event_at,
        'message' AS event_type
    FROM messages AS m
    JOIN response_base AS rb
        ON rb.response_id = m.response_id
    WHERE m.sender_role = 'employer'
      AND m.sent_at >= rb.created_at
      AND m.sent_at < rb.created_at + INTERVAL '7 day'
),
calls_7d AS (                      -- 1 строка = звонок работодателя в первые 7 суток после отклика
    SELECT
        c.response_id,
        c.employer_id,
        c.call_id::text AS event_id,
        c.call_at AS event_at,
        'call' AS event_type
    FROM calls AS c
    JOIN response_base AS rb       -- отбрасываем 8 звонков без response_id
        ON rb.response_id = c.response_id
    WHERE c.caller_role = 'employer'
      AND c.call_at >= rb.created_at
      AND c.call_at < rb.created_at + INTERVAL '7 day'
),
events AS (                        -- 1 строка = 1 коммуникация (сообщение или звонок)
    SELECT response_id, employer_id, event_id, event_at, event_type
    FROM messages_7d
    UNION ALL                      
    SELECT response_id, employer_id, event_id, event_at, event_type
    FROM calls_7d
),
timeline AS (                      -- 1 строка = 1 коммуникация + её место в последовательности 
    SELECT
        response_id,
        employer_id,
        event_id,
        event_at,
        event_type,
        ROW_NUMBER() OVER (
            PARTITION BY response_id
            ORDER BY event_at, event_type, event_id      
        ) AS event_number,
        LAG(event_at) OVER (
            PARTITION BY response_id
            ORDER BY event_at, event_type, event_id
        ) AS previous_event_at,
        LEAD(event_type) OVER (
            PARTITION BY response_id
            ORDER BY event_at, event_type, event_id
        ) AS next_event_type,
        COUNT(*) OVER (
            PARTITION BY response_id
            ORDER BY event_at, event_type, event_id
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS communications_so_far,
        FIRST_VALUE(event_type) OVER (
            PARTITION BY response_id
            ORDER BY event_at, event_type, event_id
        ) AS first_event_type,
        LAST_VALUE(event_type) OVER (
            PARTITION BY response_id
            ORDER BY event_at, event_type, event_id
            ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING   
        ) AS last_event_type
    FROM events
),
response_mart AS (                 -- ВИТРИНА: 1 строка = 1 отклик (628)
    SELECT
        rb.response_id,
        rb.employer_id,
        rb.professional_role,
        rb.response_status,
        rb.created_at,
        COUNT(t.event_id) AS communications_count,                                  --  у откликов без связи будет 0
        COUNT(CASE WHEN t.event_type = 'call' THEN 1 END) AS calls_count,
        COUNT(CASE WHEN t.event_type = 'message' THEN 1 END) AS messages_count,
        MIN(t.event_at) AS first_communication_at,
        MAX(t.first_event_type) AS first_communication_type,                        
        MAX(CASE WHEN t.event_number = 2 THEN t.event_type END) AS second_communication_type,
        MAX(t.last_event_type) AS last_communication_type,
        EXTRACT(EPOCH FROM MIN(t.event_at) - rb.created_at) / 3600.0 AS hours_to_first,
        EXTRACT(EPOCH FROM MAX(t.event_at - t.previous_event_at)) / 3600.0 AS max_gap_hours
    FROM response_base AS rb
    LEFT JOIN timeline AS t        --  отклики без коммуникаций остаются в витрине
        ON t.response_id = rb.response_id
    GROUP BY
        rb.response_id,
        rb.employer_id,
        rb.professional_role,
        rb.response_status,
        rb.created_at
)
SELECT
    COUNT(*) AS rows_cnt,
    COUNT(CASE WHEN communications_count > 0 THEN 1 END) AS responses_with_communication,
    COUNT(CASE WHEN communications_count = 0 THEN 1 END) AS responses_without_communication,
    COUNT(CASE WHEN first_communication_type = 'message' THEN 1 END) AS first_is_message,
    COUNT(CASE WHEN first_communication_type = 'call' THEN 1 END) AS first_is_call
FROM response_mart;

-- Вывод: всего строк 628; с коммуникацией 382; без коммуникации 246; первой коммуникацией было сообщение в 314
-- откликах, звонок - в 68 (314 + 68 = 382). 246 из 628 откликов не получили от работодателя ни звонка,
-- ни сообщения за 7 суток.


-- =====================================================================
-- ЗАДАНИЕ 4. Рейтинг работодателей внутри направления
-- =====================================================================
WITH response_base AS (            -- 1 строка = 1 отклик (все 628)
    SELECT
        r.response_id,
        v.employer_id,
        v.professional_role,
        r.status AS response_status,
        r.created_at
    FROM responses AS r
    JOIN vacancies AS v
        ON v.vacancy_id = r.vacancy_id
),
messages_7d AS (                   -- 1 строка = сообщение работодателя в первые 7 суток после отклика
    SELECT
        m.response_id,
        m.employer_id,
        m.message_id::text AS event_id,
        m.sent_at AS event_at,
        'message' AS event_type
    FROM messages AS m
    JOIN response_base AS rb
        ON rb.response_id = m.response_id
    WHERE m.sender_role = 'employer'
      AND m.sent_at >= rb.created_at
      AND m.sent_at < rb.created_at + INTERVAL '7 day'
),
calls_7d AS (                      -- 1 строка = звонок работодателя в первые 7 суток после отклика
    SELECT
        c.response_id,
        c.employer_id,
        c.call_id::text AS event_id,
        c.call_at AS event_at,
        'call' AS event_type
    FROM calls AS c
    JOIN response_base AS rb       -- отбрасываем 8 звонков без response_id 
        ON rb.response_id = c.response_id
    WHERE c.caller_role = 'employer'
      AND c.call_at >= rb.created_at
      AND c.call_at < rb.created_at + INTERVAL '7 day'
),
events AS (                        -- 1 строка = 1 коммуникация (сообщение или звонок)
    SELECT response_id, employer_id, event_id, event_at, event_type
    FROM messages_7d
    UNION ALL                      
    SELECT response_id, employer_id, event_id, event_at, event_type
    FROM calls_7d
),
response_mart AS (                 
    SELECT
        rb.response_id,
        rb.employer_id,
        rb.professional_role,
        rb.response_status,
        rb.created_at,
        COUNT(e.event_id) AS communications_count,
        COUNT(CASE WHEN e.event_type = 'call' THEN 1 END) AS calls_count,
        EXTRACT(EPOCH FROM MIN(e.event_at) - rb.created_at) / 3600.0 AS hours_to_first
    FROM response_base AS rb
    LEFT JOIN events AS e          -- LEFT JOIN: отклики без коммуникаций остаются
        ON e.response_id = rb.response_id
    GROUP BY
        rb.response_id,
        rb.employer_id,
        rb.professional_role,
        rb.response_status,
        rb.created_at
),
pair_stats AS (                    -- 1 строка = пара "направление + работодатель"
    SELECT
        professional_role,
        employer_id,
        COUNT(*) AS responses_cnt,
        COUNT(CASE WHEN communications_count > 0 THEN 1 END) AS processed_cnt,
        COUNT(CASE WHEN communications_count > 0 THEN 1 END)::numeric / COUNT(*) AS processed_share,
        PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY hours_to_first) AS median_hours_to_first,   -- отклики без связи (NULL) в перцентиль не попадают
        PERCENTILE_CONT(0.9) WITHIN GROUP (ORDER BY hours_to_first) AS p90_hours_to_first,
        COUNT(CASE WHEN response_status = 'invited' THEN 1 END)::numeric / COUNT(*) AS invite_conversion
    FROM response_mart
    GROUP BY
        professional_role,
        employer_id
    HAVING COUNT(*) >= 8
)
SELECT
    ranked.professional_role,
    ranked.place,
    ranked.employer_id,
    e.employer_name,
    ranked.responses_cnt,
    ranked.processed_cnt,
    ROUND(100 * ranked.processed_share, 1) AS processed_share_pct,
    ROUND(ranked.median_hours_to_first::numeric, 2) AS median_hours_to_first,
    ROUND(ranked.p90_hours_to_first::numeric, 2) AS p90_hours_to_first,
    ROUND(100 * ranked.invite_conversion, 1) AS invite_conversion_pct
FROM (
    SELECT
        ps.professional_role,
        ps.employer_id,
        ps.responses_cnt,
        ps.processed_cnt,
        ps.processed_share,
        ps.median_hours_to_first,
        ps.p90_hours_to_first,
        ps.invite_conversion,
        DENSE_RANK() OVER (        
            PARTITION BY ps.professional_role
            ORDER BY ps.processed_share DESC, ps.median_hours_to_first ASC
        ) AS place
    FROM pair_stats AS ps
) AS ranked
JOIN employers AS e
    ON e.employer_id = ranked.employer_id
WHERE ranked.place <= 2            
ORDER BY ranked.professional_role, ranked.place, ranked.employer_id;

-- ДОРАБОТКА: 
-- Вывод. Итоговый результат (professional_role | место | employer_id):
--   Аналитик данных      | 1 | 109
--   Аналитик данных      | 2 | 103
--   Дата-инженер         | 1 | 106
--   Дата-инженер         | 2 | 101
--   Продуктовый аналитик | 1 | 103
--   Продуктовый аналитик | 2 | 102
--   Разработчик          | 1 | 112
--   Разработчик          | 2 | 104
--   Тестировщик          | 1 | 107
--   Тестировщик          | 2 | 108
-- В рейтинг попали работодатели минимум с 8 откликами в направлении. Место определяет доля обработанных
-- откликов (откликов, по которым была хоть одна коммуникация за 7 суток). При равных значениях выше тот, у кого меньше
-- медиана времени до первой коммуникации. 
-- Доли обработанных откликов: 109 - 89,5%; 103 - 84,8%; 106 - 70%; 101 - 45,8%; 103 - 71%;
-- 102 - 64,4%; 112 - 83,3%; 104 - 80%; 107 - 88,2%; 108 - 62,5%.
-- Самая быстрая первая коммуникация среди этих десяти строк - у 108 (медиана 5,67 ч), но у него всего
-- 8 откликов и только 5 из них обработаны, поэтому он на 2 месте; высокая доля обработки и скорость
-- не всегда совпадают, поэтому у рейтинга два критерия.


-- =====================================================================
-- ЗАДАНИЕ 5. Скорость ответа работодателя в переписке
-- =====================================================================
WITH messages_7d AS (              -- 1 строка = сообщение любой стороны в первые 7 суток после отклика
    SELECT
        m.response_id,
        m.employer_id,
        m.message_id,
        m.sender_role,
        m.sent_at
    FROM messages AS m
    JOIN responses AS r
        ON r.response_id = m.response_id
    WHERE m.sent_at >= r.created_at
      AND m.sent_at < r.created_at + INTERVAL '7 day'
),
messages_with_previous AS (        --  кто и когда писал непосредственно перед этим сообщением в том же отклике
    SELECT
        response_id,
        employer_id,
        sender_role,
        sent_at,
        LAG(sender_role) OVER (
            PARTITION BY response_id
            ORDER BY sent_at, message_id
        ) AS previous_sender_role,
        LAG(sent_at) OVER (
            PARTITION BY response_id
            ORDER BY sent_at, message_id
        ) AS previous_sent_at
    FROM messages_7d
),
employer_replies AS (              -- 1 строка = ответ работодателя сразу после сообщения кандидата
    SELECT
        employer_id,
        EXTRACT(EPOCH FROM sent_at - previous_sent_at) / 3600.0 AS reply_hours
    FROM messages_with_previous
    WHERE sender_role = 'employer'
      AND previous_sender_role = 'applicant'
)
SELECT
    employer_id,
    COUNT(*) AS replies_cnt,
    ROUND(AVG(reply_hours)::numeric, 2) AS avg_reply_hours,
    ROUND((PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY reply_hours))::numeric, 2) AS median_reply_hours,
    ROUND((PERCENTILE_CONT(0.9) WITHIN GROUP (ORDER BY reply_hours))::numeric, 2) AS p90_reply_hours
FROM employer_replies
GROUP BY employer_id
ORDER BY median_reply_hours ASC;

-- Вывод: всего найдено ответов работодателей: 749.
-- Минимальная медиана у employer_id = 107: 3,93 ч (28 ответов). У остальных 4,12-4,93 ч, то есть в переписке
-- работодатели отвечают примерно одинаково быстро. У 105 и 108 всего 6 и 8 ответов,
-- их медианам доверять нельзя.


-- =====================================================================
-- ЗАДАНИЕ 6. Сложные типы данных
-- =====================================================================

-- 6.1. Теги звонков работодателя в первые 7 суток (call_tags - массив, в строку не превращаем).
WITH calls_7d AS (                 -- 1 строка = звонок работодателя за 7 суток
    SELECT
        c.call_id,
        c.status,
        c.call_tags
    FROM calls AS c
    JOIN responses AS r
        ON r.response_id = c.response_id
    WHERE c.caller_role = 'employer'
      AND c.call_at >= r.created_at
      AND c.call_at < r.created_at + INTERVAL '7 day'
),
valid_calls AS (                   -- 1 строка = звонок, у которого технический тег согласуется со статусом
    SELECT
        call_id,
        call_tags
    FROM calls_7d
    WHERE (status = 'successful' AND 'connected' = ANY(call_tags))
       OR (status = 'unsuccessful' AND 'no_answer' = ANY(call_tags))
       OR (status = 'error' AND 'technical_error' = ANY(call_tags))
)
SELECT
    (SELECT COUNT(*) FROM calls_7d) - COUNT(*) AS contradictory_calls,
    COUNT(*) AS valid_calls,
    COUNT(CASE WHEN 'screening' = ANY(call_tags) THEN 1 END) AS screening,
    COUNT(CASE WHEN 'interview' = ANY(call_tags) THEN 1 END) AS interview,
    COUNT(CASE WHEN 'follow_up' = ANY(call_tags) THEN 1 END) AS follow_up,
    COUNT(CASE WHEN 'details' = ANY(call_tags) THEN 1 END) AS details,
    COUNT(CASE
              WHEN 'screening' = ANY(call_tags)
                OR 'interview' = ANY(call_tags)
                OR 'follow_up' = ANY(call_tags)
                OR 'details' = ANY(call_tags)
              THEN 1
          END) AS calls_with_business_tag,
    ROUND(AVG(CARDINALITY(call_tags)), 2) AS avg_tags_per_call
FROM valid_calls;

-- Вывод: звонков работодателя за 7 суток 108; с противоречием тега и статуса - 0, то есть все 108 подходят.
-- screening = 25, interview = 31, follow_up = 29, details = 23 (25 + 31 + 29 + 23 = 108);
-- у каждого звонка ровно один бизнес-тег; среднее число тегов на звонок = 4 

-- 6.2. Метаданные сообщений работодателя за 7 суток.
WITH employer_messages_7d AS (     -- 1 строка = сообщение работодателя за 7 суток
    SELECT
        COALESCE(m.message_meta ->> 'channel', 'канал не указан') AS channel,
        (m.message_meta ->> 'is_read')::boolean AS is_read,                       -- нет ключа -> NULL
        JSONB_ARRAY_LENGTH(m.message_meta -> 'attachments') AS attachments_cnt   
    FROM messages AS m
    JOIN responses AS r
        ON r.response_id = m.response_id
    WHERE m.sender_role = 'employer'
      AND m.sent_at >= r.created_at
      AND m.sent_at < r.created_at + INTERVAL '7 day'
)
SELECT
    channel,
    COUNT(*) AS messages_cnt,
    COUNT(is_read) AS messages_with_read_flag,                                    
    COUNT(CASE WHEN is_read = FALSE THEN 1 END) AS unread_cnt,
    ROUND(100.0 * COUNT(CASE WHEN is_read = FALSE THEN 1 END) / COUNT(is_read), 1) AS unread_share_pct,
    COUNT(CASE WHEN attachments_cnt > 0 THEN 1 END) AS messages_with_attachment,
    ROUND(100.0 * COUNT(CASE WHEN attachments_cnt > 0 THEN 1 END) / COUNT(*), 1) AS attachment_share_pct
FROM employer_messages_7d
GROUP BY channel
ORDER BY channel;

-- Вывод: каналов два, сообщений без канала нет (группа "канал не указан" пуста).
--   mobile_app: 360 сообщений; признак прочтения у 360; непрочитанных 36; с вложением 14 
--   web: 628 сообщений; признак прочтения у 628; непрочитанных 52;  с вложением 25 
-- Итого 988 сообщений. Непрочитанных чуть больше в мобильном приложении (10% против 8,3%), по вложениям каналы
-- не различаются (около 4%).


-- =====================================================================
-- ЗАДАНИЕ 7. Что связано с приглашением?
-- =====================================================================
-- ДОРАБОТКА: гипотезы разделены на действия работодателя (H1) и поведение кандидата (H2).
-- Гипотезы:
--  H1 (действия работодателя). С откликами, которые закончатся приглашением, работодатель работает активнее:
--      у них выше доля откликов с коммуникацией, меньше медиана времени до первой коммуникации,
--      больше коммуникаций на отклик и чаще есть звонок.
--  H2 (поведение кандидата). Кандидаты, которых потом приглашают, чаще сами пишут работодателю.
-- Группы: "Приглашение" (invited) против "Остальные" (new, viewed, rejected).
-- Аспекты коммуникации: скорость реакции работодателя; интенсивность его работы (число коммуникаций, звонки);
--   вовлечённость кандидата (пишет ли он сам). Всего пять характеристик.
-- Новые расчёты: ответы кандидата, доля звонков среди откликов со связью,
--   доля приглашений по скорости первого контакта.

-- 7.1. Сравниваем две группы: тех, кого пригласили, и остальных.
WITH response_base AS (            -- 1 строка = 1 отклик (все 628)
    SELECT
        r.response_id,
        v.employer_id,
        v.professional_role,
        r.status AS response_status,
        r.created_at
    FROM responses AS r
    JOIN vacancies AS v
        ON v.vacancy_id = r.vacancy_id
),
messages_7d AS (                   -- 1 строка = сообщение работодателя в первые 7 суток после отклика
    SELECT
        m.response_id,
        m.employer_id,
        m.message_id::text AS event_id,
        m.sent_at AS event_at,
        'message' AS event_type
    FROM messages AS m
    JOIN response_base AS rb
        ON rb.response_id = m.response_id
    WHERE m.sender_role = 'employer'
      AND m.sent_at >= rb.created_at
      AND m.sent_at < rb.created_at + INTERVAL '7 day'
),
calls_7d AS (                      -- 1 строка = звонок работодателя в первые 7 суток после отклика
    SELECT
        c.response_id,
        c.employer_id,
        c.call_id::text AS event_id,
        c.call_at AS event_at,
        'call' AS event_type
    FROM calls AS c
    JOIN response_base AS rb       -- отбрасываем 8 звонков без response_id 
        ON rb.response_id = c.response_id
    WHERE c.caller_role = 'employer'
      AND c.call_at >= rb.created_at
      AND c.call_at < rb.created_at + INTERVAL '7 day'
),
events AS (                        -- 1 строка = 1 коммуникация (сообщение или звонок)
    SELECT response_id, employer_id, event_id, event_at, event_type
    FROM messages_7d
    UNION ALL                      
    SELECT response_id, employer_id, event_id, event_at, event_type
    FROM calls_7d
),
response_mart AS (                 
    SELECT
        rb.response_id,
        rb.employer_id,
        rb.professional_role,
        rb.response_status,
        rb.created_at,
        COUNT(e.event_id) AS communications_count,
        COUNT(CASE WHEN e.event_type = 'call' THEN 1 END) AS calls_count,
        EXTRACT(EPOCH FROM MIN(e.event_at) - rb.created_at) / 3600.0 AS hours_to_first
    FROM response_base AS rb
    LEFT JOIN events AS e          -- отклики без коммуникаций остаются
        ON e.response_id = rb.response_id
    GROUP BY
        rb.response_id,
        rb.employer_id,
        rb.professional_role,
        rb.response_status,
        rb.created_at
),
response_features AS (             -- 1 строка = отклик + признаки для сравнения
    SELECT
        rm.response_id,
        CASE WHEN rm.response_status = 'invited' THEN 'Приглашение' ELSE 'Остальные' END AS outcome_group,
        rm.communications_count,
        rm.calls_count,
        rm.hours_to_first,
        EXISTS (                   -- нужен только факт кандидат писал сам
            SELECT 1
            FROM messages AS m
            WHERE m.response_id = rm.response_id
              AND m.sender_role = 'applicant'
              AND m.sent_at >= rm.created_at
              AND m.sent_at < rm.created_at + INTERVAL '7 day'
        ) AS applicant_wrote
    FROM response_mart AS rm
)
SELECT
    outcome_group,
    COUNT(*) AS responses_cnt,
    COUNT(CASE WHEN communications_count > 0 THEN 1 END) AS with_comm_cnt,  -- сколько из них имели контакт
    --  Охват (доля откликов с контактом)
    ROUND(100.0 * COUNT(CASE WHEN communications_count > 0 THEN 1 END) / COUNT(*), 1) AS comm_share_pct,
    -- Скорость (медиана часов до первого контакта)
    ROUND((PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY hours_to_first))::numeric, 1) AS median_hours_to_first,
    -- Интенсивность (среднее число событий среди тех, у кого был контакт)
    ROUND(AVG(CASE WHEN communications_count > 0 THEN communications_count END), 2) AS avg_communications,
    ROUND(100.0 * COUNT(CASE WHEN calls_count > 0 THEN 1 END)
          / COUNT(CASE WHEN communications_count > 0 THEN 1 END), 1) AS with_call_pct,
    -- Вовлеченность (доля откликов, где кандидат сам написал)
    ROUND(100.0 * COUNT(CASE WHEN applicant_wrote THEN 1 END) / COUNT(*), 1) AS applicant_wrote_pct
FROM response_features
GROUP BY outcome_group
ORDER BY outcome_group DESC;


-- 7.2. Как скорость первого контакта связана с долей приглашений
WITH response_base AS (            -- 1 строка = 1 отклик (все 628)
    SELECT
        r.response_id,
        v.employer_id,
        v.professional_role,
        r.status AS response_status,
        r.created_at
    FROM responses AS r
    JOIN vacancies AS v
        ON v.vacancy_id = r.vacancy_id
),
messages_7d AS (                   -- 1 строка = сообщение работодателя в первые 7 суток после отклика
    SELECT
        m.response_id,
        m.employer_id,
        m.message_id::text AS event_id,
        m.sent_at AS event_at,
        'message' AS event_type
    FROM messages AS m
    JOIN response_base AS rb
        ON rb.response_id = m.response_id
    WHERE m.sender_role = 'employer'
      AND m.sent_at >= rb.created_at
      AND m.sent_at < rb.created_at + INTERVAL '7 day'
),
calls_7d AS (                      -- 1 строка = звонок работодателя в первые 7 суток после отклика
    SELECT
        c.response_id,
        c.employer_id,
        c.call_id::text AS event_id,
        c.call_at AS event_at,
        'call' AS event_type
    FROM calls AS c
    JOIN response_base AS rb       -- отбрасываем 8 звонков без response_id 
        ON rb.response_id = c.response_id
    WHERE c.caller_role = 'employer'
      AND c.call_at >= rb.created_at
      AND c.call_at < rb.created_at + INTERVAL '7 day'
),
events AS (                        -- 1 строка = 1 коммуникация (сообщение или звонок)
    SELECT response_id, employer_id, event_id, event_at, event_type
    FROM messages_7d
    UNION ALL                      
    SELECT response_id, employer_id, event_id, event_at, event_type
    FROM calls_7d
),
response_mart AS (                 -- 1 строка = 1 отклик (628)
    SELECT
        rb.response_id,
        rb.employer_id,
        rb.professional_role,
        rb.response_status,
        rb.created_at,
        COUNT(e.event_id) AS communications_count,
        COUNT(CASE WHEN e.event_type = 'call' THEN 1 END) AS calls_count,
        EXTRACT(EPOCH FROM MIN(e.event_at) - rb.created_at) / 3600.0 AS hours_to_first
    FROM response_base AS rb
    LEFT JOIN events AS e          -- LEFT JOIN: отклики без коммуникаций остаются
        ON e.response_id = rb.response_id
    GROUP BY
        rb.response_id,
        rb.employer_id,
        rb.professional_role,
        rb.response_status,
        rb.created_at
)
SELECT
    CASE
        WHEN communications_count = 0 THEN '0. нет коммуникации за 7 суток'
        WHEN hours_to_first <= 24 THEN '1. до 24 часов'
        WHEN hours_to_first <= 72 THEN '2. от 24 до 72 часов'
        ELSE '3. более 72 часов'
    END AS first_contact_speed,
    COUNT(*) AS responses_cnt,
    COUNT(CASE WHEN response_status = 'invited' THEN 1 END) AS invited_cnt,
    ROUND(100.0 * COUNT(CASE WHEN response_status = 'invited' THEN 1 END) / COUNT(*), 1) AS invite_share_pct
FROM response_mart
GROUP BY 1
ORDER BY 1;

-- ДОРАБОТКА:
-- Вывод по гипотезам. Приглашение: 92 отклика, 54 со связью; Остальные: 536 откликов, 328 со связью.
--  H1 (действия работодателя) НЕ ПОДТВЕРЖДАЕТСЯ.
--      Связь была у 58,7% приглашённых откликов и у 61,2% остальных: у приглашённых даже чуть реже.
--      Первая коммуникация приходит через 51,1 ч против 54,7 ч (медиана): разница 3,6 ч слишком мала.
--      Среднее число коммуникаций 2,78 против 2,88; хотя бы один звонок у 27,8% против 26,8%.
--      Доля приглашений почти одинакова при любой скорости: 14,8% (до 24 ч), 13,6% (24-72 ч),
--       14% (позже 72 ч) и 15,4% там, где связи не было вовсе.
--     Работодатель ведёт себя с приглашёнными и остальными практически одинаково.
--  H2 (поведение кандидата) НЕ ПОДТВЕРЖДАЕТСЯ.
--      Кандидат писал сам в 51,1% приглашённых откликов и в 55,4% остальных,
--       то есть различие есть, но оно в обратную сторону от гипотезы.
--  Итог: связи между коммуникацией за первые 7 суток и приглашением в этих данных не обнаружено: ни действия
--  работодателя, ни скорость первого контакта, ни звонок не отличают приглашённые отклики от остальных.
--  Значит, утверждение "звонок или быстрый ответ повышают шанс приглашения" не подтверждается.


-- =====================================================================
-- ЗАДАНИЕ 8. Итог исследования
-- =====================================================================
-- ДОРАБОТКА:
-- Вывод:
-- 1) После отклика работодатели выходят на связь не всегда: за первые 7 суток 246 из 628 откликов (39%) не получили ни звонка,
-- ни сообщения, а по остальным 382 откликам было 1096 коммуникаций, из них 988 сообщений и только 108 звонков.
-- 2) Первой коммуникацией чаще бывает сообщение (314 откликов против 68 со звонком), то есть основной канал работодателей - переписка.
-- 3) Данные пригодны: единственная проблема - 8 звонков без response_id (700244-700251), исключаем.
-- 4) Работодатели сильно различаются по доле обработанных откликов (задание 4): в "Аналитике данных" работодатель 109 обработал 89,5%
-- откликов, а 101 - лишь 46,1%, в "Разработчике" лидирует 112 (83,3%), а 106 обрабатывает только 28,3%.
-- 5) Различается и скорость первого контакта: медиана времени до первой коммуникации от 5,67 ч у 108 ("Тестировщик", но всего 8 откликов)
-- до 76,33 ч у 101 ("Дата-инженер").
-- 6) Когда переписка уже началась, скорость ответа почти одинакова: медиана ответа работодателя на сообщение кандидата от 3,93 ч (107)
-- до 4,93 ч (102), то есть работодатели отличаются тем, берут ли они отклик в работу и как быстро выходят на первый контакт,
-- а не скоростью ответов внутри уже начатой переписки.
-- 7) С приглашением коммуникация за 7 суток не связана: охват 58,7% против 61,2%, медиана до первой связи 51,1 против 54,7 ч,
-- звонок есть у 27,8% против 26,8%, а доля приглашений держится на уровне 13,6-15,4% при любой скорости первого контакта.
-- 8) Ограничения: учтена только первая неделя и только действия работодателя, приглашённых откликов всего 92,
-- а в части пар "работодатель - направление" лишь 8-20 откликов.


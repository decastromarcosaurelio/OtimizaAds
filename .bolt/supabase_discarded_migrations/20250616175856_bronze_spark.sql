/*
  # Criar função increment_usage_counter

  1. Nova Função
    - `increment_usage_counter` - incrementa o contador de uso de funcionalidades
    - Parâmetros: `p_user_uuid` (uuid), `p_feature_type` (text)
    - Retorna: boolean indicando sucesso
  
  2. Funcionalidade
    - Incrementa ou cria registro de uso para o usuário e funcionalidade
    - Usa período mensal atual para rastreamento
    - Evita ambiguidade de colunas usando prefixos nos parâmetros
*/

CREATE OR REPLACE FUNCTION increment_usage_counter(
  p_user_uuid UUID,
  p_feature_type TEXT
) RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_period_start TIMESTAMPTZ;
  v_period_end TIMESTAMPTZ;
  v_existing_count INTEGER;
BEGIN
  -- Calcular início e fim do período mensal atual
  v_period_start := date_trunc('month', now());
  v_period_end := v_period_start + interval '1 month';
  
  -- Verificar se já existe um registro para este usuário, funcionalidade e período
  SELECT count INTO v_existing_count
  FROM usage_tracking
  WHERE user_id = p_user_uuid
    AND feature_type = p_feature_type
    AND period_start = v_period_start;
  
  IF v_existing_count IS NULL THEN
    -- Criar novo registro
    INSERT INTO usage_tracking (
      user_id,
      feature_type,
      count,
      period_start,
      period_end
    ) VALUES (
      p_user_uuid,
      p_feature_type,
      1,
      v_period_start,
      v_period_end
    );
  ELSE
    -- Incrementar contador existente
    UPDATE usage_tracking
    SET 
      count = count + 1,
      updated_at = now()
    WHERE user_id = p_user_uuid
      AND feature_type = p_feature_type
      AND period_start = v_period_start;
  END IF;
  
  RETURN TRUE;
EXCEPTION
  WHEN OTHERS THEN
    -- Log do erro e retornar false
    RAISE WARNING 'Erro ao incrementar contador de uso: %', SQLERRM;
    RETURN FALSE;
END;
$$;

-- Dar permissão para usuários autenticados chamarem a função
GRANT EXECUTE ON FUNCTION increment_usage_counter(UUID, TEXT) TO authenticated;
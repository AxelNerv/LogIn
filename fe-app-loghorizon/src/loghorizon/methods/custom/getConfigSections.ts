import { logIn } from '../../types';
import { LOGHORIZON_UCI_PACKAGE } from '../../../constants';

export async function getConfigSections(): Promise<logIn.ConfigSection[]> {
  return uci
    .load(LOGHORIZON_UCI_PACKAGE)
    .then(() => uci.sections(LOGHORIZON_UCI_PACKAGE));
}

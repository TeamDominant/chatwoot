/* global axios */

import ApiClient from '../ApiClient';

class RemnawaveAPI extends ApiClient {
  constructor() {
    super('integrations/remnawave', { accountScoped: true });
  }

  getUser(contactId) {
    return axios.get(`${this.url}/user`, {
      params: { contact_id: contactId },
    });
  }

  performAction(contactId, actionType) {
    return axios.post(`${this.url}/user_action`, {
      contact_id: contactId,
      action_type: actionType,
    });
  }
}

export default new RemnawaveAPI();

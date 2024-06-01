


[AttributeUsage(AttributeTargets.Property)]
public class FormProperty : Request
{

    private string _name { set; get; }

    private bool _required { set; get; }

    public FormProperty(string name, bool required)
    {
        this._name = name;
        this._required = required;
    }

    public override bool Validate(object value)
    {
        if (this._required)
        {
            return value != null && !string.IsNullOrWhiteSpace(value.ToString());
        }
        return true;
    }
    public override Dictionary<string, string> Serialize(object value)
    {
        Dictionary<string, string> param = new Dictionary<string, string> { };
        if (value != null && !string.IsNullOrWhiteSpace(value.ToString()))
        {

            param.Add(this._name, value.ToString() ?? "");
        }
        return param;
    }
}
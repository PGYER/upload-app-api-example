

public abstract class Request : Attribute
{
    public abstract bool Validate(object value);
    public abstract Dictionary<string, string> Serialize(object value);
}


